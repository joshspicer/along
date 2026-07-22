package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/domain"
	"github.com/joshspicer/along/server/internal/realtime"
)

func TestWebSocketSurvivesHeartbeatAndDeliversCursorHint(t *testing.T) {
	pairID := uuid.New()
	hub := realtime.NewHub()
	api := &API{
		hub:                     hub,
		logger:                  slog.New(slog.NewTextHandler(io.Discard, nil)),
		socketHeartbeatInterval: 10 * time.Millisecond,
		socketPingTimeout:       100 * time.Millisecond,
	}
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		identity := domain.AuthIdentity{PairID: &pairID}
		api.webSocket(w, r.WithContext(context.WithValue(r.Context(), identityKey, identity)))
	})
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)

	socketURL := "ws" + strings.TrimPrefix(server.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	connection, _, err := websocket.Dial(ctx, socketURL, nil)
	if err != nil {
		t.Fatalf("dial WebSocket: %v", err)
	}
	defer connection.Close(websocket.StatusNormalClosure, "test complete")

	message := readSocketMessage(t, ctx, connection)
	if message.Type != "connected" {
		t.Fatalf("initial message type = %q, want connected", message.Type)
	}

	time.Sleep(40 * time.Millisecond)
	hub.Publish(realtime.Hint{PairID: pairID, Cursor: 42})

	message = readSocketMessage(t, ctx, connection)
	if message.Type != "cursor" || message.Cursor != 42 {
		t.Fatalf("cursor message = %#v, want cursor 42", message)
	}
}

type socketMessage struct {
	Type   string `json:"type"`
	Cursor int64  `json:"cursor"`
}

func readSocketMessage(t *testing.T, ctx context.Context, connection *websocket.Conn) socketMessage {
	t.Helper()
	_, raw, err := connection.Read(ctx)
	if err != nil {
		t.Fatalf("read WebSocket message: %v", err)
	}
	var message socketMessage
	if err := json.Unmarshal(raw, &message); err != nil {
		t.Fatalf("decode WebSocket message: %v", err)
	}
	return message
}
