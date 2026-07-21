package httpapi

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net"
	"net/http"
	"runtime/debug"
	"strings"
	"sync"
	"time"

	"github.com/joshspicer/along/server/internal/apperror"
)

type rateBucket struct {
	window time.Time
	count  int
}

type rateLimiter struct {
	mu       sync.Mutex
	buckets  map[string]rateBucket
	limit    int
	interval time.Duration
}

func newRateLimiter(limit int, interval time.Duration) *rateLimiter {
	return &rateLimiter{buckets: make(map[string]rateBucket), limit: limit, interval: interval}
}

func (l *rateLimiter) allow(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	bucket := l.buckets[key]
	if bucket.window.IsZero() || now.Sub(bucket.window) >= l.interval {
		bucket = rateBucket{window: now, count: 0}
	}
	bucket.count++
	l.buckets[key] = bucket
	if len(l.buckets) > 10_000 {
		for item, value := range l.buckets {
			if now.Sub(value.window) > 2*l.interval {
				delete(l.buckets, item)
			}
		}
	}
	return bucket.count <= l.limit
}

func (a *API) requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var bytes [16]byte
		if _, err := rand.Read(bytes[:]); err != nil {
			a.writeError(w, r, err)
			return
		}
		id := hex.EncodeToString(bytes[:])
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), requestIDKey, id)))
	})
}

func (a *API) recoverMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				a.logger.Error("panic recovered",
					"request_id", requestID(r.Context()),
					"panic", recovered,
					"stack", string(debug.Stack()),
				)
				a.writeError(w, r, apperror.New(http.StatusInternalServerError, "internal_error", "Something went wrong."))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

type responseRecorder struct {
	http.ResponseWriter
	status int
}

func (w *responseRecorder) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

func (w *responseRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := w.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, http.ErrNotSupported
	}
	return hijacker.Hijack()
}

func (w *responseRecorder) Flush() {
	_ = http.NewResponseController(w.ResponseWriter).Flush()
}

func (w *responseRecorder) WriteHeader(status int) {
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}

func (a *API) accessLogMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		recorder := &responseRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(recorder, r)
		a.logger.Log(r.Context(), slog.LevelInfo, "http request",
			"request_id", requestID(r.Context()),
			"method", r.Method,
			"path", r.URL.Path,
			"status", recorder.status,
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

func secureHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		if r.TLS != nil {
			w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
		}
		next.ServeHTTP(w, r)
	})
}

func (a *API) rateLimitMiddleware(limiter *rateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			host, _, err := net.SplitHostPort(r.RemoteAddr)
			if err != nil {
				host = r.RemoteAddr
			}
			if a.cfg.TrustProxyHeaders {
				if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); net.ParseIP(forwarded) != nil {
					host = forwarded
				}
			}
			if !limiter.allow(host, time.Now()) {
				w.Header().Set("Retry-After", "60")
				a.writeError(w, r, apperror.New(http.StatusTooManyRequests, "rate_limited", "Wait a moment and try again."))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func (a *API) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		scheme, raw, ok := strings.Cut(header, " ")
		if !ok || !strings.EqualFold(scheme, "Bearer") || strings.TrimSpace(raw) == "" {
			a.writeError(w, r, apperror.ErrUnauthorized)
			return
		}
		claimed, err := a.auth.ParseAccessToken(strings.TrimSpace(raw))
		if err != nil {
			a.writeError(w, r, apperror.ErrUnauthorized)
			return
		}
		validated, err := a.store.ValidateAuthSession(r.Context(), claimed)
		if err != nil {
			a.writeError(w, r, apperror.ErrUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), identityKey, validated)))
	})
}
