package httpapi

import (
	"context"

	"github.com/joshspicer/along/server/internal/domain"
)

type contextKey string

const (
	requestIDKey contextKey = "request_id"
	identityKey  contextKey = "identity"
)

func requestID(ctx context.Context) string {
	value, _ := ctx.Value(requestIDKey).(string)
	return value
}

func identity(ctx context.Context) domain.AuthIdentity {
	value, _ := ctx.Value(identityKey).(domain.AuthIdentity)
	return value
}
