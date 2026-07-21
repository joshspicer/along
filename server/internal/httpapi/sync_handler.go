package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/apperror"
	"github.com/joshspicer/along/server/internal/domain"
)

type syncRequest struct {
	Cursor   int64                `json:"cursor"`
	Limit    int                  `json:"limit,omitempty"`
	Commands []domain.SyncCommand `json:"commands"`
}

func (a *API) sync(w http.ResponseWriter, r *http.Request) {
	var body syncRequest
	if err := decodeJSON(w, r, &body); err != nil {
		a.writeError(w, r, err)
		return
	}
	if body.Cursor < 0 || len(body.Commands) > 100 {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	if body.Limit == 0 {
		body.Limit = 200
	}
	if body.Limit < 1 || body.Limit > 500 {
		a.writeError(w, r, apperror.ErrValidation)
		return
	}
	currentIdentity := identity(r.Context())
	results := make([]domain.SyncCommandResult, 0, len(body.Commands))
	for _, command := range body.Commands {
		result, err := a.applySyncCommand(r, currentIdentity, command)
		if err != nil {
			appError := mapError(err)
			if appError.Status >= 500 {
				a.writeError(w, r, err)
				return
			}
			result = domain.SyncCommandResult{
				ID:      command.ID,
				Applied: false,
				Error: &domain.SyncError{
					Code:    appError.Code,
					Message: appError.Message,
				},
			}
		}
		results = append(results, result)
	}
	current, err := a.store.CurrentSession(r.Context(), currentIdentity)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	events, next, err := a.store.PairEvents(r.Context(), currentIdentity, body.Cursor, body.Limit)
	if err != nil {
		a.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"server_time":     time.Now().UTC(),
		"cursor":          next,
		"events":          events,
		"has_more":        len(events) == body.Limit,
		"command_results": results,
		"current_session": current,
	})
}

func (a *API) applySyncCommand(
	r *http.Request,
	current domain.AuthIdentity,
	command domain.SyncCommand,
) (domain.SyncCommandResult, error) {
	if command.ID == uuid.Nil {
		return domain.SyncCommandResult{}, apperror.New(http.StatusUnprocessableEntity, "invalid_command", "Each command needs a stable UUID.")
	}
	result := domain.SyncCommandResult{ID: command.ID, Applied: true}
	var resource any
	switch command.Type {
	case "session.start":
		sessionID := command.EntityID
		if sessionID == nil || *sessionID == uuid.Nil {
			value := uuid.New()
			sessionID = &value
		}
		session, _, err := a.store.StartSession(r.Context(), current, command.ID, *sessionID)
		if err != nil {
			return result, err
		}
		resource = session
	case "session.import_solo":
		if command.EntityID == nil || *command.EntityID == uuid.Nil {
			return result, apperror.ErrValidation
		}
		var payload struct {
			StartedAt   time.Time `json:"started_at"`
			CompletedAt time.Time `json:"completed_at"`
		}
		if err := strictPayload(command.Payload, &payload); err != nil {
			return result, err
		}
		session, _, err := a.store.ImportSoloSession(
			r.Context(),
			current,
			command.ID,
			*command.EntityID,
			payload.StartedAt,
			payload.CompletedAt,
		)
		if err != nil {
			return result, err
		}
		resource = session
	case "session.join", "session.pause", "session.resume", "session.complete", "session.cancel":
		if command.EntityID == nil || command.ExpectedVersion == nil || *command.ExpectedVersion < 1 {
			return result, apperror.ErrValidation
		}
		action := domain.SessionAction(command.Type[len("session."):])
		var session domain.FocusSession
		var err error
		if action == domain.ActionJoin {
			session, _, err = a.store.JoinSession(
				r.Context(),
				current,
				*command.EntityID,
				command.ID,
				*command.ExpectedVersion,
			)
		} else {
			session, _, err = a.store.TransitionSession(
				r.Context(),
				current,
				*command.EntityID,
				command.ID,
				*command.ExpectedVersion,
				action,
			)
		}
		if err != nil {
			return result, err
		}
		resource = session
	case "session.note":
		if command.EntityID == nil {
			return result, apperror.ErrValidation
		}
		var payload struct {
			Body string `json:"body"`
		}
		if err := strictPayload(command.Payload, &payload); err != nil {
			return result, err
		}
		if len([]rune(payload.Body)) < 1 || len([]rune(payload.Body)) > 120 {
			return result, apperror.ErrValidation
		}
		note, _, err := a.store.AddNote(r.Context(), current, *command.EntityID, command.ID, payload.Body)
		if err != nil {
			return result, err
		}
		resource = note
	case "session.cheer":
		if command.EntityID == nil {
			return result, apperror.ErrValidation
		}
		cheer, _, err := a.store.AddCheer(r.Context(), current, *command.EntityID, command.ID)
		if err != nil {
			return result, err
		}
		resource = cheer
	default:
		return result, apperror.New(http.StatusUnprocessableEntity, "unsupported_command", "This command type is not supported.")
	}
	raw, err := json.Marshal(resource)
	if err != nil {
		return result, err
	}
	result.Resource = raw
	return result, nil
}

func strictPayload(raw json.RawMessage, destination any) error {
	if len(raw) == 0 {
		return apperror.ErrValidation
	}
	if err := json.Unmarshal(raw, destination); err != nil {
		return apperror.ErrValidation
	}
	return nil
}

func (a *API) webSocket(w http.ResponseWriter, r *http.Request) {
	current := identity(r.Context())
	if current.PairID == nil {
		a.writeError(w, r, apperror.New(http.StatusConflict, "pair_required", "Pair this account before opening a shared connection."))
		return
	}
	connection, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns:  a.originPatterns,
		CompressionMode: websocket.CompressionDisabled,
	})
	if err != nil {
		a.logger.Warn("WebSocket upgrade rejected", "request_id", requestID(r.Context()), "error", err)
		return
	}
	defer connection.Close(websocket.StatusNormalClosure, "connection closed")

	hints, unsubscribe := a.hub.Subscribe(*current.PairID)
	defer unsubscribe()
	if err := writeSocketJSON(r, connection, map[string]any{
		"type":        "connected",
		"server_time": time.Now().UTC(),
	}); err != nil {
		return
	}
	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case hint := <-hints:
			if err := writeSocketJSON(r, connection, map[string]any{
				"type":   "cursor",
				"cursor": hint.Cursor,
			}); err != nil {
				return
			}
		case <-ticker.C:
			ctx, cancel := contextWithTimeout(r, 10*time.Second)
			err := connection.Ping(ctx)
			cancel()
			if err != nil {
				return
			}
		}
	}
}

func writeSocketJSON(r *http.Request, connection *websocket.Conn, value any) error {
	raw, err := json.Marshal(value)
	if err != nil {
		return err
	}
	ctx, cancel := contextWithTimeout(r, 10*time.Second)
	defer cancel()
	return connection.Write(ctx, websocket.MessageText, raw)
}
