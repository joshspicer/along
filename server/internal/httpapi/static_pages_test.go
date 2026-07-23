package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestStaticPages(t *testing.T) {
	tests := []struct {
		name    string
		handler http.HandlerFunc
		title   string
	}{
		{name: "support", handler: supportPage, title: "<title>Along support</title>"},
		{name: "privacy", handler: privacyPage, title: "<title>Along privacy</title>"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			response := httptest.NewRecorder()
			test.handler(response, httptest.NewRequest(http.MethodGet, "/"+test.name, nil))
			if response.Code != http.StatusOK {
				t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
			}
			if got := response.Header().Get("Content-Type"); got != "text/html; charset=utf-8" {
				t.Fatalf("content type = %q", got)
			}
			if got := response.Header().Get("Content-Security-Policy"); !strings.Contains(got, "style-src 'unsafe-inline'") {
				t.Fatalf("content security policy = %q", got)
			}
			if !strings.Contains(response.Body.String(), test.title) {
				t.Fatalf("response does not contain %q", test.title)
			}
		})
	}
}
