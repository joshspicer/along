package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/domain"
)

func TestAccessTokenRoundTripAndTamper(t *testing.T) {
	t.Parallel()
	manager := NewTokenManager([]byte("0123456789abcdef0123456789abcdef"), 10*time.Minute)
	now := time.Now().UTC().Truncate(time.Second)
	manager.now = func() time.Time { return now }
	want := domain.AuthIdentity{
		AccountID:      uuid.New(),
		SessionID:      uuid.New(),
		InstallationID: uuid.New(),
	}
	raw, expires, err := manager.Issue(want)
	if err != nil {
		t.Fatal(err)
	}
	if !expires.Equal(now.Add(10 * time.Minute)) {
		t.Fatalf("expires = %v", expires)
	}
	got, err := manager.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.AccountID != want.AccountID || got.SessionID != want.SessionID ||
		got.InstallationID != want.InstallationID {
		t.Fatalf("parsed identity = %#v, want %#v", got, want)
	}
	parts := strings.Split(raw, ".")
	parts[2] = parts[2][:len(parts[2])-1] + "A"
	if _, err := manager.Parse(strings.Join(parts, ".")); err == nil {
		t.Fatal("tampered token was accepted")
	}
}

func TestOpaqueTokenRoundTrip(t *testing.T) {
	t.Parallel()
	id, raw, hash, err := NewOpaqueToken()
	if err != nil {
		t.Fatal(err)
	}
	gotID, gotHash, err := ParseOpaqueToken(raw)
	if err != nil {
		t.Fatal(err)
	}
	if gotID != id || string(gotHash) != string(hash) {
		t.Fatal("opaque token did not round trip")
	}
	for _, malformed := range []string{"", id.String(), id.String() + ".short", "invalid.value"} {
		if _, _, err := ParseOpaqueToken(malformed); err == nil {
			t.Fatalf("accepted malformed token %q", malformed)
		}
	}
}
