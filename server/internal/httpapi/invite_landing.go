package httpapi

import (
	"encoding/base64"
	"html/template"
	"net/http"

	"github.com/go-chi/chi/v5"
)

var pairInvitePage = template.Must(template.New("pair-invite").Parse(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow,noarchive">
  <title>Join in Along</title>
</head>
<body>
  <main>
    <h1>Join in Along</h1>
    <p>Open this private invitation in the Along app.</p>
    <p><a href="along:///join/{{.Token}}">Open Along</a></p>
    <p>If Along is not installed, ask the person who invited you for the app.</p>
  </main>
</body>
</html>`))

func (a *API) pairInviteLanding(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	decoded, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil || len(decoded) != 32 {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
	w.Header().Set("X-Robots-Tag", "noindex, nofollow, noarchive")
	w.WriteHeader(http.StatusOK)
	_ = pairInvitePage.Execute(w, map[string]string{"Token": token})
}
