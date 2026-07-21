package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound       = errors.New("not found")
	ErrConflict       = errors.New("conflict")
	ErrVersion        = errors.New("version conflict")
	ErrRefreshReuse   = errors.New("refresh token reuse detected")
	ErrInvalidRefresh = errors.New("invalid refresh token")
	ErrAlreadyPaired  = errors.New("account is already paired")
	ErrActiveSession  = errors.New("an active session already exists")
	ErrCooldown       = errors.New("action is on cooldown")
)

type Store struct {
	pool *pgxpool.Pool
	now  func() time.Time
}

func Open(ctx context.Context, databaseURL string) (*Store, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database configuration: %w", err)
	}
	cfg.MaxConns = 20
	cfg.MinConns = 2
	cfg.MaxConnLifetime = 30 * time.Minute
	cfg.MaxConnIdleTime = 5 * time.Minute
	cfg.HealthCheckPeriod = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("open database pool: %w", err)
	}
	return &Store{pool: pool, now: time.Now}, nil
}

func (s *Store) Close() {
	s.pool.Close()
}

func (s *Store) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}

func (s *Store) Pool() *pgxpool.Pool {
	return s.pool
}
