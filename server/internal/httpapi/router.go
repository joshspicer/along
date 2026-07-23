package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/joshspicer/along/server/internal/auth"
	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/push"
	"github.com/joshspicer/along/server/internal/realtime"
	"github.com/joshspicer/along/server/internal/store"
)

type API struct {
	cfg                     config.Config
	store                   *store.Store
	auth                    *auth.Service
	hub                     *realtime.Hub
	pushCipher              *push.Cipher
	logger                  *slog.Logger
	originPatterns          []string
	socketHeartbeatInterval time.Duration
	socketPingTimeout       time.Duration
}

func New(
	cfg config.Config,
	data *store.Store,
	authService *auth.Service,
	hub *realtime.Hub,
	pushCipher *push.Cipher,
	logger *slog.Logger,
) http.Handler {
	api := &API{
		cfg:                     cfg,
		store:                   data,
		auth:                    authService,
		hub:                     hub,
		pushCipher:              pushCipher,
		logger:                  logger,
		socketHeartbeatInterval: 25 * time.Second,
		socketPingTimeout:       10 * time.Second,
	}
	for _, origin := range cfg.WebAuthnRPOrigins {
		if parsed, err := url.Parse(origin); err == nil {
			api.originPatterns = append(api.originPatterns, parsed.Host)
		}
	}
	router := chi.NewRouter()
	router.Use(api.requestIDMiddleware)
	router.Use(api.recoverMiddleware)
	router.Use(api.accessLogMiddleware)
	router.Use(secureHeaders)
	router.Use(middleware.CleanPath)
	router.Use(middleware.StripSlashes)
	router.Use(api.rateLimitMiddleware(newRateLimiter(cfg.RateLimitPerMinute, time.Minute)))

	router.Get("/health/live", api.live)
	router.Get("/health/ready", api.ready)
	router.Get("/.well-known/apple-app-site-association", api.appleAppSiteAssociation)
	router.Get("/.well-known/assetlinks.json", api.androidAssetLinks)
	router.Get("/v1/meta", api.meta)
	router.With(api.rateLimitMiddleware(newRateLimiter(10, time.Minute))).Post(
		"/v1/diagnostics/passkey",
		api.passkeyDiagnostic,
	)
	router.With(api.rateLimitMiddleware(newRateLimiter(30, time.Minute))).Post(
		"/v1/diagnostics/events",
		api.appDiagnostics,
	)

	router.Route("/v1/auth", func(r chi.Router) {
		r.Use(api.rateLimitMiddleware(newRateLimiter(30, time.Minute)))
		r.Post("/register/options", api.registerOptions)
		r.Post("/register/finish", api.registerFinish)
		r.Post("/login/options", api.loginOptions)
		r.Post("/login/finish", api.loginFinish)
		r.Post("/recover", api.recover)
		r.Post("/refresh", api.refresh)
	})

	router.Group(func(r chi.Router) {
		r.Use(api.authenticate)
		r.Get("/v1/me", api.me)
		r.Post("/v1/auth/logout", api.logout)
		r.Get("/v1/auth/passkeys", api.passkeys)
		r.Post("/v1/auth/passkeys/options", api.addPasskeyOptions)
		r.Post("/v1/auth/passkeys/finish", api.addPasskeyFinish)
		r.Delete("/v1/auth/passkeys/{credentialID}", api.revokePasskey)
		r.Get("/v1/auth/sessions", api.authSessions)
		r.Delete("/v1/auth/sessions/{sessionID}", api.revokeAuthSession)
		r.Get("/v1/auth/installations", api.installations)
		r.Delete("/v1/auth/installations/{installationID}", api.revokeInstallation)
		r.Post("/v1/auth/recovery-codes/regenerate", api.regenerateRecoveryCodes)

		r.Get("/v1/pair", api.getPair)
		r.Post("/v1/pair/invites", api.createPairInvite)
		r.Post("/v1/pair/accept", api.acceptPairInvite)

		r.Get("/v1/sessions/current", api.currentSession)
		r.Get("/v1/sessions", api.sessionHistory)
		r.Post("/v1/sessions", api.startSession)
		r.Post("/v1/sessions/{sessionID}/join", api.joinSession)
		r.Post("/v1/sessions/{sessionID}/pause", api.pauseSession)
		r.Post("/v1/sessions/{sessionID}/resume", api.resumeSession)
		r.Post("/v1/sessions/{sessionID}/complete", api.completeSession)
		r.Post("/v1/sessions/{sessionID}/cancel", api.cancelSession)
		r.Post("/v1/sessions/{sessionID}/notes", api.addNote)
		r.Post("/v1/sessions/{sessionID}/cheers", api.addCheer)

		r.Put("/v1/push/device", api.registerPushDevice)
		r.Delete("/v1/push/device", api.revokePushDevice)
		r.Post("/v1/sync", api.sync)
		r.Get("/v1/ws", api.webSocket)
	})
	return router
}

func (a *API) live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := contextWithTimeout(r, a.cfg.ReadinessTimeout)
	defer cancel()
	if err := a.store.Ping(ctx); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ready"})
}

func (a *API) meta(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service":     "along-server",
		"api_version": "v1",
		"git_commit":  a.cfg.GitCommit,
		"server_time": time.Now().UTC(),
	})
}

func (a *API) appleAppSiteAssociation(w http.ResponseWriter, _ *http.Request) {
	appID := a.cfg.AppleTeamID + ".com.joshspicer.along"
	writeJSON(w, http.StatusOK, map[string]any{
		"applinks": map[string]any{
			"apps": []string{},
			"details": []any{map[string]any{
				"appIDs": []string{appID},
				"components": []any{
					map[string]string{"/": "/join/*", "comment": "One-time pairing links"},
					map[string]string{"/": "/focus", "comment": "Focus notification resync"},
					map[string]string{"/": "/look-back", "comment": "Note notification resync"},
				},
			}},
		},
		"webcredentials": map[string]any{"apps": []string{appID}},
	})
}

func (a *API) androidAssetLinks(w http.ResponseWriter, _ *http.Request) {
	statements := []any{}
	if len(a.cfg.AndroidSigningSHA256) > 0 {
		statements = append(statements, map[string]any{
			"relation": []string{
				"delegate_permission/common.handle_all_urls",
				"delegate_permission/common.get_login_creds",
			},
			"target": map[string]any{
				"namespace":                "android_app",
				"package_name":             "com.joshspicer.along",
				"sha256_cert_fingerprints": a.cfg.AndroidSigningSHA256,
			},
		})
	}
	writeJSON(w, http.StatusOK, statements)
}

func contextWithTimeout(r *http.Request, timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(r.Context(), timeout)
}

func normalizedBaseURL(value string) string {
	return strings.TrimRight(value, "/")
}
