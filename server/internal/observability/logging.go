package observability

import (
	"log/slog"
	"os"
	"strings"
)

func Logger(environment string) *slog.Logger {
	level := slog.LevelInfo
	if environment == "development" {
		level = slog.LevelDebug
	}
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
		ReplaceAttr: func(_ []string, attribute slog.Attr) slog.Attr {
			key := strings.ToLower(attribute.Key)
			if strings.Contains(key, "token") ||
				strings.Contains(key, "secret") ||
				strings.Contains(key, "authorization") ||
				strings.Contains(key, "credential") {
				return slog.String(attribute.Key, "[redacted]")
			}
			return attribute
		},
	})
	return slog.New(handler)
}
