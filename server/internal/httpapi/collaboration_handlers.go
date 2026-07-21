package httpapi

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/apperror"
	"github.com/joshspicer/along/server/internal/domain"
)

func (a *API) getPair(w http.ResponseWriter, r *http.Request) {
	pair, err := a.store.Pair(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"pair": pair})
}

func (a *API) createPairInvite(w http.ResponseWriter, r *http.Request) {
	var body struct{}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		a.writeError(w, r, err)
		return
	}
	raw := base64.RawURLEncoding.EncodeToString(tokenBytes)
	hash := sha256.Sum256([]byte(raw))
	inviteID := uuid.New()
	expiresAt := time.Now().UTC().Add(a.cfg.InviteTTL)
	if err := a.store.CreatePairInvite(
		r.Context(),
		identity(r.Context()).AccountID,
		inviteID,
		hash[:],
		expiresAt,
	); err != nil {
		a.writeError(w, r, err)
		return
	}
	invite := domain.PairInvite{
		ID:        inviteID,
		URL:       normalizedBaseURL(a.cfg.PublicBaseURL) + "/join/" + raw,
		ExpiresAt: expiresAt,
	}
	writeJSON(w, http.StatusCreated, map[string]any{"invite": invite})
}

func (a *API) acceptPairInvite(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Token string `json:"token"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	if decoded, err := base64.RawURLEncoding.DecodeString(body.Token); err != nil || len(decoded) != 32 {
		a.writeError(w, r, apperror.New(http.StatusNotFound, "invite_not_found", "This pairing link is invalid or expired."))
		return
	}
	hash := sha256.Sum256([]byte(body.Token))
	pair, err := a.store.AcceptPairInvite(r.Context(), identity(r.Context()).AccountID, hash[:])
	if err != nil {
		if mapError(err).Status == http.StatusNotFound {
			err = apperror.New(http.StatusNotFound, "invite_not_found", "This pairing link is invalid or expired.")
		}
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"pair": pair})
}

func (a *API) currentSession(w http.ResponseWriter, r *http.Request) {
	session, err := a.store.CurrentSession(r.Context(), identity(r.Context()))
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"session":     session,
		"server_time": time.Now().UTC(),
	})
}

func (a *API) sessionHistory(w http.ResponseWriter, r *http.Request) {
	var before *time.Time
	if raw := r.URL.Query().Get("before"); raw != "" {
		value, err := time.Parse(time.RFC3339Nano, raw)
		if err != nil {
			a.writeError(w, r, apperror.ErrValidation)
			return
		}
		before = &value
	}
	limit := 50
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 100 {
			a.writeError(w, r, apperror.ErrValidation)
			return
		}
		limit = parsed
	}
	sessions, err := a.store.SessionHistory(r.Context(), identity(r.Context()), before, limit)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"sessions": sessions})
}

func (a *API) startSession(w http.ResponseWriter, r *http.Request) {
	var body struct {
		SessionID uuid.UUID `json:"session_id"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	if body.SessionID == uuid.Nil {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	key, err := idempotencyKey(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	session, replayed, err := a.store.StartSession(r.Context(), identity(r.Context()), key, body.SessionID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeReplay(w, replayed)
	status := http.StatusCreated
	if replayed {
		status = http.StatusOK
	}
	writeJSON(w, status, map[string]any{"session": session, "server_time": time.Now().UTC()})
}

func (a *API) joinSession(w http.ResponseWriter, r *http.Request) {
	a.transition(w, r, domain.ActionJoin)
}

func (a *API) pauseSession(w http.ResponseWriter, r *http.Request) {
	a.transition(w, r, domain.ActionPause)
}

func (a *API) resumeSession(w http.ResponseWriter, r *http.Request) {
	a.transition(w, r, domain.ActionResume)
}

func (a *API) completeSession(w http.ResponseWriter, r *http.Request) {
	a.transition(w, r, domain.ActionComplete)
}

func (a *API) cancelSession(w http.ResponseWriter, r *http.Request) {
	a.transition(w, r, domain.ActionCancel)
}

func (a *API) transition(w http.ResponseWriter, r *http.Request, action domain.SessionAction) {
	sessionID, err := sessionID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	key, err := idempotencyKey(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	var body struct {
		ExpectedVersion int64 `json:"expected_version"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	if body.ExpectedVersion < 1 {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	var session domain.FocusSession
	var replayed bool
	if action == domain.ActionJoin {
		session, replayed, err = a.store.JoinSession(
			r.Context(),
			identity(r.Context()),
			sessionID,
			key,
			body.ExpectedVersion,
		)
	} else {
		session, replayed, err = a.store.TransitionSession(
			r.Context(),
			identity(r.Context()),
			sessionID,
			key,
			body.ExpectedVersion,
			action,
		)
	}
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeReplay(w, replayed)
	writeJSON(w, http.StatusOK, map[string]any{"session": session, "server_time": time.Now().UTC()})
}

func (a *API) addNote(w http.ResponseWriter, r *http.Request) {
	sessionID, err := sessionID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	key, err := idempotencyKey(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	var body struct {
		Body string `json:"body"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	body.Body = strings.TrimSpace(body.Body)
	if len([]rune(body.Body)) < 1 || len([]rune(body.Body)) > 120 {
		a.writeError(w, r, apperror.New(http.StatusUnprocessableEntity, "invalid_note", "Use a note between 1 and 120 characters."))
		return
	}
	note, replayed, err := a.store.AddNote(r.Context(), identity(r.Context()), sessionID, key, body.Body)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeReplay(w, replayed)
	writeJSON(w, http.StatusCreated, map[string]any{"note": note})
}

func (a *API) addCheer(w http.ResponseWriter, r *http.Request) {
	sessionID, err := sessionID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	key, err := idempotencyKey(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	var body struct{}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	cheer, replayed, err := a.store.AddCheer(r.Context(), identity(r.Context()), sessionID, key)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeReplay(w, replayed)
	writeJSON(w, http.StatusCreated, map[string]any{"cheer": cheer})
}

func (a *API) registerPushDevice(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Token       string `json:"token"`
		Environment string `json:"environment"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	body.Token = strings.ToLower(strings.TrimSpace(body.Token))
	decoded, err := hex.DecodeString(body.Token)
	if err != nil || len(decoded) != 32 {
		a.writeError(w, r, apperror.New(http.StatusUnprocessableEntity, "invalid_push_token", "The APNs device token is invalid."))
		return
	}
	if body.Environment != "sandbox" && body.Environment != "production" {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	ciphertext, err := a.pushCipher.Encrypt([]byte(body.Token))
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	current := identity(r.Context())
	if err := a.store.RegisterPushDevice(
		r.Context(),
		current.AccountID,
		current.InstallationID,
		body.Token,
		ciphertext,
		body.Environment,
		a.cfg.APNSTopic,
	); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func (a *API) revokePushDevice(w http.ResponseWriter, r *http.Request) {
	current := identity(r.Context())
	if err := a.store.RevokePushDevice(r.Context(), current.AccountID, current.InstallationID); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func sessionID(r *http.Request) (uuid.UUID, error) {
	id, err := uuid.Parse(chi.URLParam(r, "sessionID"))
	if err != nil {
		return uuid.Nil, apperror.ErrValidation
	}
	return id, nil
}

func idempotencyKey(r *http.Request) (uuid.UUID, error) {
	value := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.Nil, apperror.New(http.StatusBadRequest, "idempotency_key_required", "Send a UUID Idempotency-Key header.")
	}
	return id, nil
}

func writeReplay(w http.ResponseWriter, replayed bool) {
	if replayed {
		w.Header().Set("Idempotent-Replayed", "true")
	}
}
