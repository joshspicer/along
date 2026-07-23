package httpapi

import (
	"context"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestPairInviteLandingOpensAppWithoutIndexing(t *testing.T) {
	token := base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	request := httptest.NewRequest(http.MethodGet, "/join/"+token, nil)
	routeContext := chi.NewRouteContext()
	routeContext.URLParams.Add("token", token)
	request = request.WithContext(context.WithValue(request.Context(), chi.RouteCtxKey, routeContext))
	response := httptest.NewRecorder()

	(&API{}).pairInviteLanding(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
	if !strings.Contains(response.Body.String(), "along:///join/"+token) {
		t.Fatal("landing page missing app link")
	}
	if response.Header().Get("X-Robots-Tag") == "" {
		t.Fatal("landing page allows indexing")
	}
}

func TestDiagnosticRequestPathRedactsInviteToken(t *testing.T) {
	if got := diagnosticRequestPath("/join/secret-token"); got != "/join/:id" {
		t.Fatalf("path = %q", got)
	}
}
