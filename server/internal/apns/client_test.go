package apns

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestAPNSPayloadIsPrivacySafeAndResyncs(t *testing.T) {
	t.Parallel()
	payload, err := apnsPayload(json.RawMessage(`{
		"title":"Along",
		"body":"Your partner started a focus.",
		"deep_link":"along:///focus"
	}`))
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, want := range []string{"Your partner started a focus.", "along:///focus", `"resync":true`} {
		if !strings.Contains(text, want) {
			t.Fatalf("payload %s does not contain %q", text, want)
		}
	}
	for _, forbidden := range []string{"Jamie", "Alex", "note body", "session_id"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("payload leaked %q", forbidden)
		}
	}
}
