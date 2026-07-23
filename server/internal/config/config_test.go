package config

import (
	"os"
	"strings"
	"testing"
	"time"
)

func TestLoadDerivesPasskeyConfigurationFromDomain(t *testing.T) {
	t.Setenv("ALONG_DOMAIN", "focus.example")
	t.Setenv("DATABASE_URL", "postgres://along:secret@database/along")
	t.Setenv("JWT_SIGNING_KEY", "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=")
	t.Setenv("PUSH_ENCRYPTION_KEY", "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=")
	for _, key := range []string{"PUBLIC_BASE_URL", "WEBAUTHN_RP_ID", "WEBAUTHN_RP_ORIGINS"} {
		if err := os.Unsetenv(key); err != nil {
			t.Fatalf("unset %s: %v", key, err)
		}
	}

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.PublicBaseURL != "https://focus.example" {
		t.Fatalf("PublicBaseURL = %q", cfg.PublicBaseURL)
	}
	if cfg.WebAuthnRPID != "focus.example" {
		t.Fatalf("WebAuthnRPID = %q", cfg.WebAuthnRPID)
	}
	if len(cfg.WebAuthnRPOrigins) != 1 || cfg.WebAuthnRPOrigins[0] != "https://focus.example" {
		t.Fatalf("WebAuthnRPOrigins = %#v", cfg.WebAuthnRPOrigins)
	}
}

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
