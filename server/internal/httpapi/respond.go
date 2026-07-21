package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime"
	"net/http"

	"github.com/jackc/pgx/v5"

	"github.com/joshspicer/along/server/internal/apperror"
	"github.com/joshspicer/along/server/internal/store"
)

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code      string         `json:"code"`
	Message   string         `json:"message"`
	RequestID string         `json:"request_id"`
	Details   map[string]any `json:"details,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if status == http.StatusNoContent {
		return
	}
	_ = json.NewEncoder(w).Encode(value)
}

func (a *API) writeError(w http.ResponseWriter, r *http.Request, err error) {
	appError := mapError(err)
	if appError.RetryAfter > 0 {
		w.Header().Set("Retry-After", http.StatusText(appError.RetryAfter))
	}
	if appError.Status >= 500 {
		a.logger.Error("request failed",
			"request_id", requestID(r.Context()),
			"method", r.Method,
			"path", r.URL.Path,
			"error", err,
		)
	} else {
		a.logger.Log(r.Context(), slog.LevelDebug, "request rejected",
			"request_id", requestID(r.Context()),
			"method", r.Method,
			"path", r.URL.Path,
			"code", appError.Code,
		)
	}
	writeJSON(w, appError.Status, errorEnvelope{Error: errorBody{
		Code:      appError.Code,
		Message:   appError.Message,
		RequestID: requestID(r.Context()),
		Details:   appError.Details,
	}})
}

func mapError(err error) *apperror.Error {
	switch {
	case err == nil:
		return apperror.New(http.StatusInternalServerError, "internal_error", "Something went wrong.")
	case errors.Is(err, store.ErrNotFound), errors.Is(err, pgx.ErrNoRows):
		return apperror.ErrNotFound
	case errors.Is(err, store.ErrAlreadyPaired):
		return apperror.New(http.StatusConflict, "already_paired", "This account already belongs to a pair.")
	case errors.Is(err, store.ErrActiveSession):
		return apperror.New(http.StatusConflict, "active_session_exists", "A focus session is already running.")
	case errors.Is(err, store.ErrVersion):
		return &apperror.Error{
			Code:    "version_conflict",
			Message: "The session changed on another device. Sync and try again.",
			Status:  http.StatusConflict,
			Details: map[string]any{"resync_required": true},
		}
	case errors.Is(err, store.ErrCooldown):
		return apperror.New(http.StatusTooManyRequests, "cheer_cooldown", "Give the last cheer a moment.")
	case errors.Is(err, store.ErrConflict):
		return apperror.ErrConflict
	default:
		return apperror.As(err)
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, destination any) error {
	mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return apperror.New(http.StatusUnsupportedMediaType, "unsupported_media_type", "Use application/json.")
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return apperror.Wrap(http.StatusBadRequest, "invalid_json", "The JSON body is not valid.", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return apperror.New(http.StatusBadRequest, "invalid_json", "Send exactly one JSON object.")
	}
	return nil
}
