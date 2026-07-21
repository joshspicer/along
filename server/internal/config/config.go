package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Environment          string
	HTTPAddress          string
	DatabaseURL          string
	PublicBaseURL        string
	WebAuthnRPID         string
	WebAuthnRPOrigins    []string
	JWTSigningKey        []byte
	AccessTokenTTL       time.Duration
	RefreshTokenTTL      time.Duration
	ChallengeTTL         time.Duration
	InviteTTL            time.Duration
	PushEncryptionKey    []byte
	RateLimitPerMinute   int
	ShutdownTimeout      time.Duration
	ReadinessTimeout     time.Duration
	GitCommit            string
	APNSTeamID           string
	APNSKeyID            string
	APNSKeyPath          string
	APNSTopic            string
	APNSEnvironment      string
	APNSPollInterval     time.Duration
	APNSBatchSize        int
	AllowInsecureDevKeys bool
}

func Load() (Config, error) {
	cfg := Config{
		Environment:        env("ALONG_ENV", "development"),
		HTTPAddress:        env("HTTP_ADDRESS", ":8080"),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		PublicBaseURL:      env("PUBLIC_BASE_URL", "https://localhost"),
		WebAuthnRPID:       env("WEBAUTHN_RP_ID", "localhost"),
		WebAuthnRPOrigins:  splitCSV(env("WEBAUTHN_RP_ORIGINS", "https://localhost")),
		AccessTokenTTL:     duration("ACCESS_TOKEN_TTL", 10*time.Minute),
		RefreshTokenTTL:    duration("REFRESH_TOKEN_TTL", 30*24*time.Hour),
		ChallengeTTL:       duration("WEBAUTHN_CHALLENGE_TTL", 5*time.Minute),
		InviteTTL:          duration("PAIR_INVITE_TTL", 48*time.Hour),
		RateLimitPerMinute: integer("RATE_LIMIT_PER_MINUTE", 120),
		ShutdownTimeout:    duration("SHUTDOWN_TIMEOUT", 15*time.Second),
		ReadinessTimeout:   duration("READINESS_TIMEOUT", 2*time.Second),
		GitCommit:          env("GIT_COMMIT", "unknown"),
		APNSTeamID:         os.Getenv("APNS_TEAM_ID"),
		APNSKeyID:          os.Getenv("APNS_KEY_ID"),
		APNSKeyPath:        env("APNS_KEY_PATH", "/run/secrets/apns_key"),
		APNSTopic:          env("APNS_TOPIC", "com.joshspicer.along"),
		APNSEnvironment:    env("APNS_ENVIRONMENT", "sandbox"),
		APNSPollInterval:   duration("APNS_POLL_INTERVAL", 2*time.Second),
		APNSBatchSize:      integer("APNS_BATCH_SIZE", 50),
	}
	cfg.AllowInsecureDevKeys, _ = strconv.ParseBool(os.Getenv("ALONG_ALLOW_INSECURE_DEV_KEYS"))

	var err error
	cfg.JWTSigningKey, err = secret("JWT_SIGNING_KEY", cfg.AllowInsecureDevKeys, "along-development-jwt-key-change-me")
	if err != nil {
		return Config{}, err
	}
	cfg.PushEncryptionKey, err = secret("PUSH_ENCRYPTION_KEY", cfg.AllowInsecureDevKeys, "along-dev-push-key-32-bytes-long")
	if err != nil {
		return Config{}, err
	}
	if err := cfg.ValidateAPI(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) ValidateAPI() error {
	var errs []error
	if c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required"))
	} else if _, err := url.Parse(c.DatabaseURL); err != nil {
		errs = append(errs, fmt.Errorf("DATABASE_URL: %w", err))
	}
	if c.Environment == "production" && c.AllowInsecureDevKeys {
		errs = append(errs, errors.New("insecure development keys are forbidden in production"))
	}
	if len(c.JWTSigningKey) < 32 {
		errs = append(errs, errors.New("JWT_SIGNING_KEY must decode to at least 32 bytes"))
	}
	if len(c.PushEncryptionKey) != 32 {
		errs = append(errs, errors.New("PUSH_ENCRYPTION_KEY must decode to exactly 32 bytes"))
	}
	if c.WebAuthnRPID == "" || len(c.WebAuthnRPOrigins) == 0 {
		errs = append(errs, errors.New("WebAuthn RP ID and at least one origin are required"))
	}
	for _, origin := range c.WebAuthnRPOrigins {
		u, err := url.Parse(origin)
		if err != nil || u.Scheme == "" || u.Host == "" {
			errs = append(errs, fmt.Errorf("invalid WebAuthn origin %q", origin))
		}
		if c.Environment == "production" && u.Scheme != "https" {
			errs = append(errs, fmt.Errorf("production WebAuthn origin %q must use HTTPS", origin))
		}
	}
	if c.AccessTokenTTL <= 0 || c.AccessTokenTTL > 15*time.Minute {
		errs = append(errs, errors.New("ACCESS_TOKEN_TTL must be between zero and 15 minutes"))
	}
	if c.RefreshTokenTTL < 24*time.Hour {
		errs = append(errs, errors.New("REFRESH_TOKEN_TTL must be at least 24 hours"))
	}
	if c.RateLimitPerMinute < 10 {
		errs = append(errs, errors.New("RATE_LIMIT_PER_MINUTE must be at least 10"))
	}
	return errors.Join(errs...)
}

func (c Config) ValidateAPNS() error {
	var errs []error
	if c.APNSTeamID == "" {
		errs = append(errs, errors.New("APNS_TEAM_ID is required"))
	}
	if c.APNSKeyID == "" {
		errs = append(errs, errors.New("APNS_KEY_ID is required"))
	}
	if c.APNSTopic == "" {
		errs = append(errs, errors.New("APNS_TOPIC is required"))
	}
	if c.APNSEnvironment != "sandbox" && c.APNSEnvironment != "production" {
		errs = append(errs, errors.New("APNS_ENVIRONMENT must be sandbox or production"))
	}
	if c.APNSBatchSize < 1 || c.APNSBatchSize > 500 {
		errs = append(errs, errors.New("APNS_BATCH_SIZE must be between 1 and 500"))
	}
	return errors.Join(errs...)
}

func env(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func duration(name string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return -1
	}
	return parsed
}

func integer(name string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return -1
	}
	return parsed
}

func splitCSV(value string) []string {
	var values []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			values = append(values, item)
		}
	}
	return values
}

func secret(name string, allowDevelopment bool, developmentValue string) ([]byte, error) {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		if !allowDevelopment {
			return nil, fmt.Errorf("%s is required (base64 encoded)", name)
		}
		value = base64.StdEncoding.EncodeToString([]byte(developmentValue))
	}
	decoded, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		return nil, fmt.Errorf("%s must be valid base64: %w", name, err)
	}
	return decoded, nil
}
