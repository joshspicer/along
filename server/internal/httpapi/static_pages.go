package httpapi

import (
	_ "embed"
	"net/http"
)

//go:embed static/support.html
var supportHTML []byte

//go:embed static/privacy.html
var privacyHTML []byte

func supportPage(w http.ResponseWriter, _ *http.Request) {
	writeStaticHTML(w, supportHTML)
}

func privacyPage(w http.ResponseWriter, _ *http.Request) {
	writeStaticHTML(w, privacyHTML)
}

func writeStaticHTML(w http.ResponseWriter, content []byte) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(content)
}
