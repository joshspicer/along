package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"unicode/utf8"
)

func TestPasskeyDiagnosticReturnsRequestIDAndBoundsDescription(t *testing.T) {
	var logs bytes.Buffer
	api := &API{logger: slog.New(slog.NewJSONHandler(&logs, nil))}
	body := `{"platform":"ios","operation":"register","relying_party_id":"along.spicer.dev","error_domain":"com.apple.AuthenticationServices.AuthorizationError","error_code":1004,"error_description":"` + strings.Repeat("x", 600) + `","app_commit":"abc123"}`
	request := httptest.NewRequest(http.MethodPost, "/v1/diagnostics/passkey", strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request = request.WithContext(withRequestID(request.Context(), "diagnostic-123"))
	response := httptest.NewRecorder()

	api.passkeyDiagnostic(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("status = %d", response.Code)
	}
	var result map[string]string
	if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result["diagnostic_id"] != "diagnostic-123" {
		t.Fatalf("diagnostic_id = %q", result["diagnostic_id"])
	}
	if strings.Contains(logs.String(), strings.Repeat("x", 501)) {
		t.Fatal("diagnostic description was not bounded")
	}
	if strings.Contains(logs.String(), "challenge") || strings.Contains(logs.String(), "credential") {
		t.Fatal("diagnostic log contains credential material")
	}
}

func TestBoundedPreservesValidUTF8(t *testing.T) {
	got := bounded(strings.Repeat("é", 300), 501)
	if !utf8.ValidString(got) {
		t.Fatal("bounded returned invalid UTF-8")
	}
	if len(got) > 501 {
		t.Fatalf("bounded length = %d", len(got))
	}
}

func withRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}
