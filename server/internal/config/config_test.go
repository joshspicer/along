package config

import (
	"strings"
	"testing"
	"time"
)

func TestValidateAPIRejectsMalformedProductionWebAuthnOrigin(t *testing.T) {
	cfg := Config{
		Environment:        "production",
		DatabaseURL:        "postgres://along:secret@database/along",
		WebAuthnRPID:       "along.example",
		WebAuthnRPOrigins:  []string{"%zz"},
		JWTSigningKey:      []byte("0123456789abcdef0123456789abcdef"),
		PushEncryptionKey:  []byte("0123456789abcdef0123456789abcdef"),
		AccessTokenTTL:     10 * time.Minute,
		RefreshTokenTTL:    30 * 24 * time.Hour,
		RateLimitPerMinute: 120,
	}

	err := cfg.ValidateAPI()
	if err == nil {
		t.Fatal("ValidateAPI accepted a malformed WebAuthn origin")
	}
	if !strings.Contains(err.Error(), `invalid WebAuthn origin "%zz"`) {
		t.Fatalf("ValidateAPI error = %q, want malformed-origin detail", err)
	}
}
