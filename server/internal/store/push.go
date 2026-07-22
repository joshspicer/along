package store

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type PushJob struct {
	ID          uuid.UUID
	DeviceID    uuid.UUID
	TokenCipher []byte
	Environment string
	Topic       string
	Payload     json.RawMessage
	Attempts    int
}

func (s *Store) RegisterPushDevice(
	ctx context.Context,
	accountID, installationID uuid.UUID,
	token string,
	tokenCipher []byte,
	environment, topic string,
) error {
	hash := sha256.Sum256([]byte(token))
	tag, err := s.pool.Exec(ctx, `
		INSERT INTO push_devices
		  (id, account_id, device_install_id, token_hash, token_ciphertext, environment, topic)
		SELECT $1, $2, $3, $4, $5, $6, $7
		WHERE EXISTS (
			SELECT 1 FROM device_installs
			WHERE id = $3 AND account_id = $2 AND revoked_at IS NULL
		)
		ON CONFLICT (token_hash) DO UPDATE
		SET account_id = EXCLUDED.account_id,
		    device_install_id = EXCLUDED.device_install_id,
		    token_ciphertext = EXCLUDED.token_ciphertext,
		    environment = EXCLUDED.environment,
		    topic = EXCLUDED.topic,
		    updated_at = clock_timestamp(),
		    revoked_at = NULL`,
		uuid.New(),
		accountID,
		installationID,
		hash[:],
		tokenCipher,
		environment,
		topic,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) RevokePushDevice(ctx context.Context, accountID, installationID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE push_devices
		SET revoked_at = COALESCE(revoked_at, clock_timestamp())
		WHERE account_id = $1 AND device_install_id = $2`,
		accountID,
		installationID,
	)
	return err
}

func (s *Store) ClaimPushJobs(ctx context.Context, limit int, lockFor time.Duration) ([]PushJob, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	rows, err := tx.Query(ctx, `
		WITH claimed AS (
			SELECT j.id, d.id AS device_id, d.token_ciphertext, d.environment,
			       d.topic, j.payload, j.attempts
			FROM notification_jobs j
			JOIN push_devices d ON d.id = j.push_device_id AND d.revoked_at IS NULL
			WHERE j.sent_at IS NULL
			  AND j.failed_at IS NULL
			  AND j.available_at <= clock_timestamp()
			  AND (j.locked_until IS NULL OR j.locked_until < clock_timestamp())
			ORDER BY j.created_at, d.created_at
			FOR UPDATE OF j SKIP LOCKED
			LIMIT $1
		)
		UPDATE notification_jobs j
		SET locked_until = clock_timestamp() + ($2 * interval '1 second')
		FROM claimed c
		WHERE j.id = c.id
		RETURNING c.id, c.device_id, c.token_ciphertext, c.environment,
		          c.topic, c.payload, c.attempts`,
		limit,
		int(lockFor.Seconds()),
	)
	if err != nil {
		return nil, err
	}
	var jobs []PushJob
	for rows.Next() {
		var job PushJob
		if err := rows.Scan(
			&job.ID,
			&job.DeviceID,
			&job.TokenCipher,
			&job.Environment,
			&job.Topic,
			&job.Payload,
			&job.Attempts,
		); err != nil {
			rows.Close()
			return nil, err
		}
		jobs = append(jobs, job)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return jobs, nil
}

func (s *Store) MarkPushSent(ctx context.Context, jobID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notification_jobs
		SET sent_at = clock_timestamp(), locked_until = NULL, last_error = NULL
		WHERE id = $1`,
		jobID,
	)
	return err
}

func (s *Store) RetryPush(ctx context.Context, jobID uuid.UUID, availableAt time.Time, reason string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notification_jobs
		SET attempts = attempts + 1, available_at = $2, locked_until = NULL, last_error = $3
		WHERE id = $1`,
		jobID,
		availableAt,
		reason,
	)
	return err
}

func (s *Store) FailPush(ctx context.Context, jobID uuid.UUID, reason string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notification_jobs
		SET attempts = attempts + 1, failed_at = clock_timestamp(),
		    locked_until = NULL, last_error = $2
		WHERE id = $1`,
		jobID,
		reason,
	)
	return err
}

func (s *Store) RevokePushToken(ctx context.Context, deviceID uuid.UUID, reason string) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx, `
		UPDATE push_devices
		SET revoked_at = COALESCE(revoked_at, clock_timestamp())
		WHERE id = $1`,
		deviceID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	_, err = tx.Exec(ctx, `
		UPDATE notification_jobs
		SET failed_at = COALESCE(failed_at, clock_timestamp()),
		    locked_until = NULL, last_error = $2
		WHERE push_device_id = $1 AND sent_at IS NULL AND failed_at IS NULL`,
		deviceID,
		reason,
	)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func IsNoRows(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
