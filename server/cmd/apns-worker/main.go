package main

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/joshspicer/along/server/internal/apns"
	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/observability"
	"github.com/joshspicer/along/server/internal/push"
	"github.com/joshspicer/along/server/internal/store"
)

func main() {
	cfg, err := config.Load()
	if err == nil {
		err = cfg.ValidateAPNS()
	}
	if err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(1)
	}
	logger := observability.Logger(cfg.Environment)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	data, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("open database", "error", err)
		os.Exit(1)
	}
	defer data.Close()
	cipher, err := push.NewCipher(cfg.PushEncryptionKey)
	if err != nil {
		logger.Error("initialize push encryption", "error", err)
		os.Exit(1)
	}
	client, err := apns.NewClient(cfg, cipher, logger)
	if err != nil {
		logger.Error("initialize APNs client", "error", err)
		os.Exit(1)
	}
	worker := apns.NewWorker(cfg, data, client, logger)
	logger.Info("APNs worker started", "environment", cfg.APNSEnvironment)
	if err := worker.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
		logger.Error("APNs worker stopped unexpectedly", "error", err)
		os.Exit(1)
	}
	logger.Info("APNs worker stopped")
}
