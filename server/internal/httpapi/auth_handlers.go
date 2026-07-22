package httpapi

import (
	"encoding/base64"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/apperror"
	"github.com/joshspicer/along/server/internal/auth"
	"github.com/joshspicer/along/server/internal/domain"
)

func (a *API) registerOptions(w http.ResponseWriter, r *http.Request) {
	var body struct {
		DisplayName string `json:"display_name"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	options, err := a.auth.BeginAccountRegistration(r.Context(), body.DisplayName)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, options)
}

func (a *API) registerFinish(w http.ResponseWriter, r *http.Request) {
	challengeID, err := ceremonyID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	device, err := deviceInfo(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	result, err := a.auth.FinishAccountRegistration(
		r.Context(),
		challengeID,
		r,
		device,
		r.Header.Get("X-Along-Passkey-Label"),
	)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, result)
}

func (a *API) loginOptions(w http.ResponseWriter, r *http.Request) {
	var body struct{}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	options, err := a.auth.BeginLogin(r.Context())
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, options)
}

func (a *API) loginFinish(w http.ResponseWriter, r *http.Request) {
	challengeID, err := ceremonyID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	device, err := deviceInfo(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	result, err := a.auth.FinishLogin(r.Context(), challengeID, r, device)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) recover(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RecoveryHandle string `json:"recovery_handle"`
		Code           string `json:"code"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	device, err := deviceInfo(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	result, err := a.auth.Recover(r.Context(), body.RecoveryHandle, body.Code, device)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) refresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	result, err := a.auth.Refresh(r.Context(), body.RefreshToken)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	account, err := a.store.Account(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"account": account})
}

func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	current := identity(r.Context())
	if err := a.store.RevokeSession(r.Context(), current.AccountID, current.SessionID, "logout"); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func (a *API) passkeys(w http.ResponseWriter, r *http.Request) {
	records, err := a.store.ListCredentials(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	items := make([]map[string]any, 0, len(records))
	for _, record := range records {
		items = append(items, map[string]any{
			"id":           base64.RawURLEncoding.EncodeToString(record.ID),
			"label":        record.Label,
			"created_at":   record.CreatedAt,
			"last_used_at": record.LastUsedAt,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"passkeys": items})
}

func (a *API) addPasskeyOptions(w http.ResponseWriter, r *http.Request) {
	var body struct{}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	options, err := a.auth.BeginAddPasskey(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, options)
}

func (a *API) addPasskeyFinish(w http.ResponseWriter, r *http.Request) {
	challengeID, err := ceremonyID(r)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	err = a.auth.FinishAddPasskey(
		r.Context(),
		identity(r.Context()).AccountID,
		challengeID,
		r,
		r.Header.Get("X-Along-Passkey-Label"),
	)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"created": true})
}

func (a *API) revokePasskey(w http.ResponseWriter, r *http.Request) {
	credentialID, err := auth.DecodeCredentialID(chi.URLParam(r, "credentialID"))
	if err != nil {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	if err := a.store.RevokeCredential(r.Context(), identity(r.Context()).AccountID, credentialID); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func (a *API) authSessions(w http.ResponseWriter, r *http.Request) {
	current := identity(r.Context())
	records, err := a.store.ListSessions(r.Context(), current.AccountID, current.SessionID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"sessions": records})
}

func (a *API) revokeAuthSession(w http.ResponseWriter, r *http.Request) {
	sessionID, err := uuid.Parse(chi.URLParam(r, "sessionID"))
	if err != nil {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	if err := a.store.RevokeSession(r.Context(), identity(r.Context()).AccountID, sessionID, "user_revoked"); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func (a *API) installations(w http.ResponseWriter, r *http.Request) {
	records, err := a.store.ListInstallations(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"installations": records})
}

func (a *API) revokeInstallation(w http.ResponseWriter, r *http.Request) {
	installationID, err := uuid.Parse(chi.URLParam(r, "installationID"))
	if err != nil {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	if err := a.store.RevokeInstallation(r.Context(), identity(r.Context()).AccountID, installationID); err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusNoContent, nil)
}

func (a *API) regenerateRecoveryCodes(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Confirm bool `json:"confirm"`
	}
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	if !body.Confirm {
		a.writeError(w, r, apperror.New(http.StatusUnprocessableEntity, "confirmation_required", "Confirm that old recovery codes will stop working."))
		return
	}
	kit, err := a.auth.RegenerateRecoveryCodes(r.Context(), identity(r.Context()).AccountID)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"recovery_kit": kit})
}

func ceremonyID(r *http.Request) (uuid.UUID, error) {
	value := strings.TrimSpace(r.Header.Get("X-Along-Challenge"))
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.Nil, apperror.New(http.StatusBadRequest, "invalid_challenge", "The ceremony challenge is missing or invalid.")
	}
	return id, nil
}

func deviceInfo(r *http.Request) (domain.DeviceInfo, error) {
	id, err := uuid.Parse(strings.TrimSpace(r.Header.Get("X-Along-Installation-ID")))
	if err != nil {
		return domain.DeviceInfo{}, apperror.New(http.StatusBadRequest, "invalid_installation", "A stable installation ID is required.")
	}
	platform := strings.ToLower(strings.TrimSpace(r.Header.Get("X-Along-Platform")))
	if platform != "ios" && platform != "android" {
		return domain.DeviceInfo{}, apperror.New(http.StatusBadRequest, "invalid_platform", "Platform must be ios or android.")
	}
	name := strings.TrimSpace(r.Header.Get("X-Along-Device-Name"))
	if name == "" || len([]rune(name)) > 120 {
		return domain.DeviceInfo{}, apperror.New(http.StatusBadRequest, "invalid_device_name", "Use a device name between 1 and 120 characters.")
	}
	return domain.DeviceInfo{ID: id, Platform: platform, Name: name}, nil
}
