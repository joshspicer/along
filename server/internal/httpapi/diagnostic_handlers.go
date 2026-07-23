package httpapi

import (
	"log/slog"
	"net/http"
	"strings"
	"unicode/utf8"

	"github.com/joshspicer/along/server/internal/apperror"
)

type passkeyDiagnosticRequest struct {
	Platform         string `json:"platform"`
	Operation        string `json:"operation"`
	RelyingPartyID   string `json:"relying_party_id"`
	ErrorDomain      string `json:"error_domain"`
	ErrorCode        int    `json:"error_code"`
	ErrorDescription string `json:"error_description"`
	AppCommit        string `json:"app_commit"`
}

func (a *API) passkeyDiagnostic(w http.ResponseWriter, r *http.Request) {
	var body passkeyDiagnosticRequest
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	body.Platform = bounded(body.Platform, 20)
	body.Operation = bounded(body.Operation, 20)
	body.RelyingPartyID = bounded(body.RelyingPartyID, 253)
	body.ErrorDomain = bounded(body.ErrorDomain, 100)
	body.ErrorDescription = bounded(body.ErrorDescription, 500)
	body.AppCommit = bounded(body.AppCommit, 64)
	if body.Platform != "ios" && body.Platform != "android" {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	if body.Operation != "register" && body.Operation != "authenticate" && body.Operation != "add" {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}

	a.logger.Log(r.Context(), slog.LevelWarn, "passkey diagnostic",
		"diagnostic_id", requestID(r.Context()),
		"platform", body.Platform,
		"operation", body.Operation,
		"relying_party_id", body.RelyingPartyID,
		"error_domain", body.ErrorDomain,
		"error_code", body.ErrorCode,
		"error_description", body.ErrorDescription,
		"app_commit", body.AppCommit,
	)
	writeJSON(w, http.StatusAccepted, map[string]string{
		"diagnostic_id": requestID(r.Context()),
	})
}

func bounded(value string, limit int) string {
	value = strings.TrimSpace(value)
	if len(value) <= limit {
		return value
	}
	value = value[:limit]
	for !utf8.ValidString(value) {
		value = value[:len(value)-1]
	}
	return value
}
