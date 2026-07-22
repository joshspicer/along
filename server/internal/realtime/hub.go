package realtime

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Hint struct {
	PairID uuid.UUID `json:"pair_id"`
	Cursor int64     `json:"cursor"`
}

type Hub struct {
	mu          sync.RWMutex
	subscribers map[uuid.UUID]map[chan Hint]struct{}
}

func NewHub() *Hub {
	return &Hub{subscribers: make(map[uuid.UUID]map[chan Hint]struct{})}
}

func (h *Hub) Subscribe(pairID uuid.UUID) (<-chan Hint, func()) {
	channel := make(chan Hint, 8)
	h.mu.Lock()
	if h.subscribers[pairID] == nil {
		h.subscribers[pairID] = make(map[chan Hint]struct{})
	}
	h.subscribers[pairID][channel] = struct{}{}
	h.mu.Unlock()
	return channel, func() {
		h.mu.Lock()
		delete(h.subscribers[pairID], channel)
		if len(h.subscribers[pairID]) == 0 {
			delete(h.subscribers, pairID)
		}
		h.mu.Unlock()
	}
}

func (h *Hub) Publish(hint Hint) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for channel := range h.subscribers[hint.PairID] {
		select {
		case channel <- hint:
		default:
			// A cursor hint may be coalesced; clients always replay from durable storage.
		}
	}
}

func Listen(ctx context.Context, databaseURL string, hub *Hub, logger *slog.Logger) {
	delay := time.Second
	for ctx.Err() == nil {
		if err := listenOnce(ctx, databaseURL, hub, logger); err != nil && !errors.Is(err, context.Canceled) {
			logger.Error("pair event listener disconnected", "error", err, "retry_in", delay)
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(delay):
		}
		if delay < 30*time.Second {
			delay *= 2
		}
	}
}

func listenOnce(ctx context.Context, databaseURL string, hub *Hub, logger *slog.Logger) error {
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return err
	}
	defer conn.Close(context.Background())
	if _, err := conn.Exec(ctx, `LISTEN pair_events`); err != nil {
		return err
	}
	logger.Info("pair event listener connected")
	for {
		notification, err := conn.WaitForNotification(ctx)
		if err != nil {
			return err
		}
		var hint Hint
		if err := json.Unmarshal([]byte(notification.Payload), &hint); err != nil {
			logger.Warn("ignored malformed pair event notification", "error", err)
			continue
		}
		hub.Publish(hint)
	}
}
