package migrations

import "embed"

// Files contains the immutable SQL migration set shipped with the server image.
//
//go:embed *.sql
var Files embed.FS
