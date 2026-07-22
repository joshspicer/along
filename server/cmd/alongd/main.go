package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joshspicer/along/server/internal/auth"
	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/httpapi"
	"github.com/joshspicer/along/server/internal/observability"
	"github.com/joshspicer/along/server/internal/push"
	"github.com/joshspicer/along/server/internal/realtime"
	"github.com/joshspicer/along/server/internal/store"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(1)
	}
	logger := observability.Logger(cfg.Environment)
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	data, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("open database", "error", err)
		os.Exit(1)
	}
	defer data.Close()
	startupCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	if err := data.Ping(startupCtx); err != nil {
		cancel()
		logger.Error("database unavailable", "error", err)
		os.Exit(1)
	}
	cancel()

	authService, err := auth.NewService(cfg, data)
	if err != nil {
		logger.Error("initialize authentication", "error", err)
		os.Exit(1)
	}
	pushCipher, err := push.NewCipher(cfg.PushEncryptionKey)
	if err != nil {
		logger.Error("initialize push encryption", "error", err)
		os.Exit(1)
	}
	hub := realtime.NewHub()
	go realtime.Listen(ctx, cfg.DatabaseURL, hub, logger)
	handler := httpapi.New(cfg, data, authService, hub, pushCipher, logger)
	server := &http.Server{
		Addr:              cfg.HTTPAddress,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       90 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	go func() {
		logger.Info("Along API listening",
			"address", cfg.HTTPAddress,
			"environment", cfg.Environment,
			"git_commit", cfg.GitCommit,
		)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("HTTP server failed", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer shutdownCancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		_ = server.Close()
	}
	logger.Info("Along API stopped")
}
