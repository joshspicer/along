package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/joshspicer/along/server/internal/config"
)

func TestAppleAppSiteAssociationUsesConfiguredTeamID(t *testing.T) {
	api := &API{cfg: config.Config{AppleTeamID: "N7C8DEK852"}}
	response := httptest.NewRecorder()

	api.appleAppSiteAssociation(response, httptest.NewRequest(http.MethodGet, "/.well-known/apple-app-site-association", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
	if got := response.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("Content-Type = %q", got)
	}
	var document struct {
		WebCredentials struct {
			Apps []string `json:"apps"`
		} `json:"webcredentials"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
		t.Fatalf("decode AASA: %v", err)
	}
	want := "N7C8DEK852.com.joshspicer.along"
	if len(document.WebCredentials.Apps) != 1 || document.WebCredentials.Apps[0] != want {
		t.Fatalf("webcredentials apps = %#v, want %q", document.WebCredentials.Apps, want)
	}
}

func TestAndroidAssetLinksOmitsInvalidPlaceholder(t *testing.T) {
	api := &API{cfg: config.Config{}}
	response := httptest.NewRecorder()

	api.androidAssetLinks(response, httptest.NewRequest(http.MethodGet, "/.well-known/assetlinks.json", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
	var statements []any
	if err := json.Unmarshal(response.Body.Bytes(), &statements); err != nil {
		t.Fatalf("decode asset links: %v", err)
	}
	if len(statements) != 0 {
		t.Fatalf("asset links = %#v, want empty list", statements)
	}
}
