package apns

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/tls"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/push"
	"github.com/joshspicer/along/server/internal/store"
)

type tokenProvider struct {
	teamID string
	keyID  string
	key    *ecdsa.PrivateKey
	mu     sync.Mutex
	token  string
	issued time.Time
}

func newTokenProvider(teamID, keyID, keyPath string) (*tokenProvider, error) {
	pem, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("read APNs key: %w", err)
	}
	key, err := jwt.ParseECPrivateKeyFromPEM(pem)
	if err != nil {
		return nil, fmt.Errorf("parse APNs key: %w", err)
	}
	return &tokenProvider{teamID: teamID, keyID: keyID, key: key}, nil
}

func (p *tokenProvider) get(now time.Time) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.token != "" && now.Sub(p.issued) < 50*time.Minute {
		return p.token, nil
	}
	claims := jwt.RegisteredClaims{
		Issuer:   p.teamID,
		IssuedAt: jwt.NewNumericDate(now),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = p.keyID
	signed, err := token.SignedString(p.key)
	if err != nil {
		return "", err
	}
	p.token = signed
	p.issued = now
	return signed, nil
}

type Client struct {
	http   *http.Client
	tokens *tokenProvider
	cipher *push.Cipher
	logger *slog.Logger
}

type Result struct {
	StatusCode int
	Reason     string
	RetryAfter time.Duration
}

func NewClient(cfg config.Config, cipher *push.Cipher, logger *slog.Logger) (*Client, error) {
	provider, err := newTokenProvider(cfg.APNSTeamID, cfg.APNSKeyID, cfg.APNSKeyPath)
	if err != nil {
		return nil, err
	}
	transport := &http.Transport{
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 15 * time.Second,
		TLSClientConfig:       &tls.Config{MinVersion: tls.VersionTLS12},
	}
	return &Client{
		http:   &http.Client{Transport: transport, Timeout: 30 * time.Second},
		tokens: provider,
		cipher: cipher,
		logger: logger,
	}, nil
}

func (c *Client) Send(ctx context.Context, job store.PushJob) (Result, error) {
	tokenBytes, err := c.cipher.Decrypt(job.TokenCipher)
	if err != nil {
		return Result{}, fmt.Errorf("decrypt device token: %w", err)
	}
	deviceToken := string(tokenBytes)
	if deviceToken == "" || strings.ContainsAny(deviceToken, "/?#") {
		return Result{}, errors.New("invalid device token")
	}
	host := "https://api.sandbox.push.apple.com"
	if job.Environment == "production" {
		host = "https://api.push.apple.com"
	}
	authToken, err := c.tokens.get(time.Now().UTC())
	if err != nil {
		return Result{}, fmt.Errorf("sign APNs provider token: %w", err)
	}
	payload, err := apnsPayload(job.Payload)
	if err != nil {
		return Result{}, err
	}
	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		host+"/3/device/"+url.PathEscape(deviceToken),
		bytes.NewReader(payload),
	)
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("authorization", "bearer "+authToken)
	req.Header.Set("apns-topic", job.Topic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")
	req.Header.Set("apns-expiration", "0")
	req.Header.Set("content-type", "application/json")

	response, err := c.http.Do(req)
	if err != nil {
		return Result{}, err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 4096))
	if err != nil {
		return Result{}, err
	}
	result := Result{StatusCode: response.StatusCode}
	if len(body) > 0 {
		var errorBody struct {
			Reason string `json:"reason"`
		}
		if json.Unmarshal(body, &errorBody) == nil {
			result.Reason = errorBody.Reason
		}
	}
	if retry := response.Header.Get("Retry-After"); retry != "" {
		if seconds, err := strconv.Atoi(retry); err == nil && seconds > 0 {
			result.RetryAfter = time.Duration(seconds) * time.Second
		}
	}
	return result, nil
}

func apnsPayload(raw json.RawMessage) ([]byte, error) {
	var source struct {
		Title    string `json:"title"`
		Body     string `json:"body"`
		DeepLink string `json:"deep_link"`
	}
	if err := json.Unmarshal(raw, &source); err != nil {
		return nil, fmt.Errorf("decode notification payload: %w", err)
	}
	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": source.Title,
				"body":  source.Body,
			},
			"sound": "default",
		},
		"deep_link": source.DeepLink,
		"resync":    true,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	if len(encoded) > 4096 {
		return nil, errors.New("APNs payload exceeds 4 KiB")
	}
	return encoded, nil
}

type Worker struct {
	cfg    config.Config
	store  *store.Store
	client *Client
	logger *slog.Logger
}

func NewWorker(cfg config.Config, data *store.Store, client *Client, logger *slog.Logger) *Worker {
	return &Worker{cfg: cfg, store: data, client: client, logger: logger}
}

func (w *Worker) Run(ctx context.Context) error {
	ticker := time.NewTicker(w.cfg.APNSPollInterval)
	defer ticker.Stop()
	for {
		if err := w.processBatch(ctx); err != nil && !errors.Is(err, context.Canceled) {
			w.logger.Error("process APNs batch", "error", err)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func (w *Worker) processBatch(ctx context.Context) error {
	jobs, err := w.store.ClaimPushJobs(ctx, w.cfg.APNSBatchSize, time.Minute)
	if err != nil {
		return err
	}
	for _, job := range jobs {
		if err := w.process(ctx, job); err != nil {
			w.logger.Error("process APNs job", "job_id", job.ID, "error", err)
		}
	}
	return nil
}

func (w *Worker) process(ctx context.Context, job store.PushJob) error {
	result, err := w.client.Send(ctx, job)
	if err != nil {
		return w.retry(ctx, job, "transport_error", 0)
	}
	switch {
	case result.StatusCode == http.StatusOK:
		return w.store.MarkPushSent(ctx, job.ID)
	case result.StatusCode == http.StatusGone ||
		(result.StatusCode == http.StatusBadRequest &&
			(result.Reason == "BadDeviceToken" || result.Reason == "DeviceTokenNotForTopic")):
		if err := w.store.RevokePushToken(ctx, job.DeviceID, result.Reason); err != nil {
			return err
		}
		return nil
	case result.StatusCode == http.StatusTooManyRequests || result.StatusCode >= 500:
		return w.retry(ctx, job, result.Reason, result.RetryAfter)
	default:
		reason := result.Reason
		if reason == "" {
			reason = fmt.Sprintf("apns_status_%d", result.StatusCode)
		}
		return w.store.FailPush(ctx, job.ID, reason)
	}
}

func (w *Worker) retry(ctx context.Context, job store.PushJob, reason string, retryAfter time.Duration) error {
	if job.Attempts >= 10 {
		return w.store.FailPush(ctx, job.ID, "retry_limit: "+reason)
	}
	delay := retryAfter
	if delay <= 0 {
		exponent := job.Attempts
		if exponent > 10 {
			exponent = 10
		}
		delay = time.Second * time.Duration(1<<exponent)
		var random [8]byte
		if _, err := rand.Read(random[:]); err == nil {
			delay += time.Duration(binary.BigEndian.Uint64(random[:])%1000) * time.Millisecond
		}
	}
	if delay > time.Hour {
		delay = time.Hour
	}
	return w.store.RetryPush(ctx, job.ID, time.Now().UTC().Add(delay), reason)
}
