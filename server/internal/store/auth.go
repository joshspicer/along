package store

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/joshspicer/along/server/internal/domain"
)

type WebAuthnAccount struct {
	domain.Account
	Credentials []json.RawMessage
}

type Challenge struct {
	ID          uuid.UUID
	AccountID   *uuid.UUID
	Purpose     string
	SessionData json.RawMessage
}

type RecoveryCodeRecord struct {
	Position int
	Hash     string
}

type CredentialRecord struct {
	ID         []byte     `json:"id"`
	Label      string     `json:"label"`
	CreatedAt  time.Time  `json:"created_at"`
	LastUsedAt *time.Time `json:"last_used_at,omitempty"`
}

type AuthSessionRecord struct {
	ID               uuid.UUID `json:"id"`
	InstallationID   uuid.UUID `json:"installation_id"`
	InstallationName string    `json:"installation_name"`
	Platform         string    `json:"platform"`
	CreatedAt        time.Time `json:"created_at"`
	LastSeenAt       time.Time `json:"last_seen_at"`
	Current          bool      `json:"current"`
}

type InstallationRecord struct {
	ID         uuid.UUID `json:"id"`
	Name       string    `json:"name"`
	Platform   string    `json:"platform"`
	CreatedAt  time.Time `json:"created_at"`
	LastSeenAt time.Time `json:"last_seen_at"`
}

func (s *Store) CreatePendingAccount(
	ctx context.Context,
	accountID uuid.UUID,
	userHandle []byte,
	displayName string,
	recoveryHandle string,
) (domain.Account, error) {
	var account domain.Account
	err := s.pool.QueryRow(ctx, `
		INSERT INTO accounts (id, webauthn_user_handle, display_name, recovery_handle)
		VALUES ($1, $2, $3, $4)
		RETURNING id, display_name, recovery_handle, webauthn_user_handle, status, created_at`,
		accountID,
		userHandle,
		displayName,
		recoveryHandle,
	).Scan(
		&account.ID,
		&account.DisplayName,
		&account.RecoveryHandle,
		&account.WebAuthnUserID,
		&account.Status,
		&account.CreatedAt,
	)
	if err != nil {
		return domain.Account{}, fmt.Errorf("create pending account: %w", err)
	}
	return account, nil
}

func (s *Store) DeletePendingAccount(ctx context.Context, accountID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1 AND status = 'pending'`, accountID)
	return err
}

func (s *Store) CreateChallenge(
	ctx context.Context,
	id uuid.UUID,
	accountID *uuid.UUID,
	purpose string,
	sessionData []byte,
	expiresAt time.Time,
) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO auth_challenges (id, account_id, purpose, session_data, expires_at)
		VALUES ($1, $2, $3, $4, $5)`,
		id,
		accountID,
		purpose,
		sessionData,
		expiresAt,
	)
	return err
}

func (s *Store) ConsumeChallenge(ctx context.Context, id uuid.UUID, purpose string) (Challenge, error) {
	var challenge Challenge
	err := s.pool.QueryRow(ctx, `
		UPDATE auth_challenges
		SET consumed_at = clock_timestamp()
		WHERE id = $1
		  AND purpose = $2
		  AND consumed_at IS NULL
		  AND expires_at > clock_timestamp()
		RETURNING id, account_id, purpose, session_data`,
		id,
		purpose,
	).Scan(&challenge.ID, &challenge.AccountID, &challenge.Purpose, &challenge.SessionData)
	if errors.Is(err, pgx.ErrNoRows) {
		return Challenge{}, ErrNotFound
	}
	return challenge, err
}

func (s *Store) GetWebAuthnAccountByID(ctx context.Context, accountID uuid.UUID) (WebAuthnAccount, error) {
	return s.getWebAuthnAccount(ctx, `a.id = $1`, accountID)
}

func (s *Store) GetWebAuthnAccountByHandle(ctx context.Context, handle []byte) (WebAuthnAccount, error) {
	return s.getWebAuthnAccount(ctx, `a.webauthn_user_handle = $1`, handle)
}

func (s *Store) getWebAuthnAccount(ctx context.Context, predicate string, value any) (WebAuthnAccount, error) {
	var account WebAuthnAccount
	var credentials []byte
	query := `
		SELECT a.id, a.display_name, a.recovery_handle, a.webauthn_user_handle,
		       a.status, a.created_at,
		       COALESCE(
		         jsonb_agg(c.credential ORDER BY c.created_at)
		           FILTER (WHERE c.credential_id IS NOT NULL AND c.revoked_at IS NULL),
		         '[]'::jsonb
		       )
		FROM accounts a
		LEFT JOIN webauthn_credentials c ON c.account_id = a.id
		WHERE ` + predicate + ` AND a.status IN ('pending', 'active')
		GROUP BY a.id`
	err := s.pool.QueryRow(ctx, query, value).Scan(
		&account.ID,
		&account.DisplayName,
		&account.RecoveryHandle,
		&account.WebAuthnUserID,
		&account.Status,
		&account.CreatedAt,
		&credentials,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return WebAuthnAccount{}, ErrNotFound
	}
	if err != nil {
		return WebAuthnAccount{}, err
	}
	if err := json.Unmarshal(credentials, &account.Credentials); err != nil {
		return WebAuthnAccount{}, fmt.Errorf("decode credentials: %w", err)
	}
	return account, nil
}

func (s *Store) ActivateAccount(
	ctx context.Context,
	accountID uuid.UUID,
	credentialID []byte,
	credentialJSON []byte,
	credentialLabel string,
	recoveryHashes []string,
	device domain.DeviceInfo,
	authSessionID uuid.UUID,
	sessionExpiresAt time.Time,
	refreshID uuid.UUID,
	refreshHash []byte,
	refreshExpiresAt time.Time,
) (domain.AuthIdentity, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx, `
		UPDATE accounts
		SET status = 'active', activated_at = clock_timestamp()
		WHERE id = $1 AND status = 'pending'`,
		accountID,
	)
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	if tag.RowsAffected() != 1 {
		return domain.AuthIdentity{}, ErrConflict
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO webauthn_credentials (credential_id, account_id, credential, label)
		VALUES ($1, $2, $3, $4)`,
		credentialID,
		accountID,
		credentialJSON,
		credentialLabel,
	); err != nil {
		return domain.AuthIdentity{}, err
	}
	for position, hash := range recoveryHashes {
		if _, err := tx.Exec(ctx, `
			INSERT INTO recovery_codes (account_id, position, code_hash)
			VALUES ($1, $2, $3)`,
			accountID,
			position,
			hash,
		); err != nil {
			return domain.AuthIdentity{}, err
		}
	}
	if err := createSession(ctx, tx, accountID, credentialID, device, authSessionID, sessionExpiresAt, refreshID, refreshID, nil, refreshHash, refreshExpiresAt); err != nil {
		return domain.AuthIdentity{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.AuthIdentity{}, err
	}
	return domain.AuthIdentity{
		AccountID:      accountID,
		SessionID:      authSessionID,
		InstallationID: device.ID,
	}, nil
}

func (s *Store) CreateLoginSession(
	ctx context.Context,
	accountID uuid.UUID,
	credentialID []byte,
	credentialJSON []byte,
	device domain.DeviceInfo,
	authSessionID uuid.UUID,
	sessionExpiresAt time.Time,
	refreshID uuid.UUID,
	refreshHash []byte,
	refreshExpiresAt time.Time,
) (domain.AuthIdentity, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx, `
		UPDATE webauthn_credentials
		SET credential = $3, last_used_at = clock_timestamp()
		WHERE credential_id = $1 AND account_id = $2 AND revoked_at IS NULL`,
		credentialID,
		accountID,
		credentialJSON,
	)
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	if tag.RowsAffected() != 1 {
		return domain.AuthIdentity{}, ErrNotFound
	}
	if err := createSession(ctx, tx, accountID, credentialID, device, authSessionID, sessionExpiresAt, refreshID, refreshID, nil, refreshHash, refreshExpiresAt); err != nil {
		return domain.AuthIdentity{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.AuthIdentity{}, err
	}
	return domain.AuthIdentity{AccountID: accountID, SessionID: authSessionID, InstallationID: device.ID}, nil
}

func createSession(
	ctx context.Context,
	tx pgx.Tx,
	accountID uuid.UUID,
	credentialID []byte,
	device domain.DeviceInfo,
	authSessionID uuid.UUID,
	sessionExpiresAt time.Time,
	refreshID uuid.UUID,
	familyID uuid.UUID,
	parentID *uuid.UUID,
	refreshHash []byte,
	refreshExpiresAt time.Time,
) error {
	if _, err := tx.Exec(ctx, `
		INSERT INTO device_installs (id, account_id, platform, name)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (id, account_id) DO UPDATE
		SET platform = EXCLUDED.platform,
		    name = EXCLUDED.name,
		    last_seen_at = clock_timestamp(),
		    revoked_at = NULL`,
		device.ID,
		accountID,
		device.Platform,
		device.Name,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO auth_sessions
		  (id, account_id, device_install_id, credential_id, expires_at)
		VALUES ($1, $2, $3, $4, $5)`,
		authSessionID,
		accountID,
		device.ID,
		nullableBytes(credentialID),
		sessionExpiresAt,
	); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `
		INSERT INTO refresh_tokens
		  (id, family_id, auth_session_id, parent_id, token_hash, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		refreshID,
		familyID,
		authSessionID,
		parentID,
		refreshHash,
		refreshExpiresAt,
	)
	return err
}

func nullableBytes(value []byte) any {
	if len(value) == 0 {
		return nil
	}
	return value
}

func (s *Store) AddCredential(
	ctx context.Context,
	accountID uuid.UUID,
	credentialID []byte,
	credentialJSON []byte,
	label string,
) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO webauthn_credentials (credential_id, account_id, credential, label)
		VALUES ($1, $2, $3, $4)`,
		credentialID,
		accountID,
		credentialJSON,
		label,
	)
	return err
}

func (s *Store) RecoveryCodes(ctx context.Context, recoveryHandle string) (domain.Account, []RecoveryCodeRecord, error) {
	var account domain.Account
	err := s.pool.QueryRow(ctx, `
		SELECT id, display_name, recovery_handle, webauthn_user_handle, status, created_at
		FROM accounts
		WHERE recovery_handle = $1 AND status = 'active'`,
		recoveryHandle,
	).Scan(
		&account.ID,
		&account.DisplayName,
		&account.RecoveryHandle,
		&account.WebAuthnUserID,
		&account.Status,
		&account.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Account{}, nil, ErrNotFound
	}
	if err != nil {
		return domain.Account{}, nil, err
	}
	rows, err := s.pool.Query(ctx, `
		SELECT position, code_hash
		FROM recovery_codes
		WHERE account_id = $1 AND used_at IS NULL
		ORDER BY position`,
		account.ID,
	)
	if err != nil {
		return domain.Account{}, nil, err
	}
	defer rows.Close()
	var codes []RecoveryCodeRecord
	for rows.Next() {
		var code RecoveryCodeRecord
		if err := rows.Scan(&code.Position, &code.Hash); err != nil {
			return domain.Account{}, nil, err
		}
		codes = append(codes, code)
	}
	return account, codes, rows.Err()
}

func (s *Store) UseRecoveryCode(
	ctx context.Context,
	accountID uuid.UUID,
	position int,
	device domain.DeviceInfo,
	authSessionID uuid.UUID,
	sessionExpiresAt time.Time,
	refreshID uuid.UUID,
	refreshHash []byte,
	refreshExpiresAt time.Time,
) (domain.AuthIdentity, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx, `
		UPDATE recovery_codes
		SET used_at = clock_timestamp()
		WHERE account_id = $1 AND position = $2 AND used_at IS NULL`,
		accountID,
		position,
	)
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	if tag.RowsAffected() != 1 {
		return domain.AuthIdentity{}, ErrConflict
	}
	if err := createSession(ctx, tx, accountID, nil, device, authSessionID, sessionExpiresAt, refreshID, refreshID, nil, refreshHash, refreshExpiresAt); err != nil {
		return domain.AuthIdentity{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.AuthIdentity{}, err
	}
	return domain.AuthIdentity{AccountID: accountID, SessionID: authSessionID, InstallationID: device.ID}, nil
}

func (s *Store) RotateRefresh(
	ctx context.Context,
	oldID uuid.UUID,
	oldHash []byte,
	newID uuid.UUID,
	newHash []byte,
	newExpiresAt time.Time,
) (domain.AuthIdentity, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	defer tx.Rollback(ctx)

	var familyID, sessionID, accountID, installationID uuid.UUID
	var tokenHash []byte
	var consumedAt, revokedAt *time.Time
	var expiresAt time.Time
	var sessionRevoked, installRevoked *time.Time
	var sessionExpires time.Time
	err = tx.QueryRow(ctx, `
		SELECT r.family_id, r.auth_session_id, r.token_hash, r.expires_at,
		       r.consumed_at, r.revoked_at,
		       s.account_id, s.device_install_id, s.expires_at, s.revoked_at,
		       d.revoked_at
		FROM refresh_tokens r
		JOIN auth_sessions s ON s.id = r.auth_session_id
		JOIN device_installs d ON d.id = s.device_install_id AND d.account_id = s.account_id
		JOIN accounts a ON a.id = s.account_id AND a.status = 'active'
		WHERE r.id = $1
		FOR UPDATE OF r, s`,
		oldID,
	).Scan(
		&familyID,
		&sessionID,
		&tokenHash,
		&expiresAt,
		&consumedAt,
		&revokedAt,
		&accountID,
		&installationID,
		&sessionExpires,
		&sessionRevoked,
		&installRevoked,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.AuthIdentity{}, ErrInvalidRefresh
	}
	if err != nil {
		return domain.AuthIdentity{}, err
	}

	now := s.now().UTC()
	if subtle.ConstantTimeCompare(tokenHash, oldHash) != 1 {
		return domain.AuthIdentity{}, ErrInvalidRefresh
	}
	if consumedAt != nil {
		if _, err := tx.Exec(ctx, `
			UPDATE refresh_tokens SET revoked_at = COALESCE(revoked_at, $2) WHERE family_id = $1`,
			familyID,
			now,
		); err != nil {
			return domain.AuthIdentity{}, err
		}
		if _, err := tx.Exec(ctx, `
			UPDATE auth_sessions
			SET revoked_at = COALESCE(revoked_at, $2), revoke_reason = 'refresh_reuse'
			WHERE id = $1`,
			sessionID,
			now,
		); err != nil {
			return domain.AuthIdentity{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return domain.AuthIdentity{}, err
		}
		return domain.AuthIdentity{}, ErrRefreshReuse
	}
	if revokedAt != nil || sessionRevoked != nil || installRevoked != nil ||
		now.After(expiresAt) || now.After(sessionExpires) {
		return domain.AuthIdentity{}, ErrInvalidRefresh
	}

	tag, err := tx.Exec(ctx, `
		UPDATE refresh_tokens
		SET consumed_at = $2, replacement_id = $3
		WHERE id = $1 AND consumed_at IS NULL`,
		oldID,
		now,
		newID,
	)
	if err != nil {
		return domain.AuthIdentity{}, err
	}
	if tag.RowsAffected() != 1 {
		return domain.AuthIdentity{}, ErrInvalidRefresh
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO refresh_tokens
		  (id, family_id, auth_session_id, parent_id, token_hash, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		newID,
		familyID,
		sessionID,
		oldID,
		newHash,
		newExpiresAt,
	); err != nil {
		return domain.AuthIdentity{}, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE auth_sessions SET last_seen_at = $2 WHERE id = $1`,
		sessionID,
		now,
	); err != nil {
		return domain.AuthIdentity{}, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE device_installs SET last_seen_at = $3 WHERE id = $1 AND account_id = $2`,
		installationID,
		accountID,
		now,
	); err != nil {
		return domain.AuthIdentity{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.AuthIdentity{}, err
	}
	return domain.AuthIdentity{
		AccountID:      accountID,
		SessionID:      sessionID,
		InstallationID: installationID,
	}, nil
}

func (s *Store) ValidateAuthSession(ctx context.Context, claimed domain.AuthIdentity) (domain.AuthIdentity, error) {
	var identity = claimed
	err := s.pool.QueryRow(ctx, `
		SELECT a.display_name, pm.pair_id
		FROM auth_sessions s
		JOIN accounts a ON a.id = s.account_id
		JOIN device_installs d ON d.id = s.device_install_id AND d.account_id = s.account_id
		LEFT JOIN webauthn_credentials c ON c.credential_id = s.credential_id
		LEFT JOIN pair_members pm ON pm.account_id = a.id
		WHERE s.id = $1
		  AND s.account_id = $2
		  AND s.device_install_id = $3
		  AND s.revoked_at IS NULL
		  AND s.expires_at > clock_timestamp()
		  AND d.revoked_at IS NULL
		  AND a.status = 'active'
		  AND (s.credential_id IS NULL OR c.revoked_at IS NULL)`,
		claimed.SessionID,
		claimed.AccountID,
		claimed.InstallationID,
	).Scan(&identity.DisplayName, &identity.PairID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.AuthIdentity{}, ErrNotFound
	}
	return identity, err
}

func (s *Store) Account(ctx context.Context, accountID uuid.UUID) (domain.Account, error) {
	var account domain.Account
	err := s.pool.QueryRow(ctx, `
		SELECT a.id, a.display_name, a.recovery_handle, a.webauthn_user_handle,
		       a.status, a.created_at, pm.pair_id, COALESCE(partner.display_name, ''),
		       (SELECT count(*) FROM webauthn_credentials c
		        WHERE c.account_id = a.id AND c.revoked_at IS NULL)
		FROM accounts a
		LEFT JOIN pair_members pm ON pm.account_id = a.id
		LEFT JOIN pair_members other ON other.pair_id = pm.pair_id AND other.account_id <> a.id
		LEFT JOIN accounts partner ON partner.id = other.account_id
		WHERE a.id = $1 AND a.status = 'active'`,
		accountID,
	).Scan(
		&account.ID,
		&account.DisplayName,
		&account.RecoveryHandle,
		&account.WebAuthnUserID,
		&account.Status,
		&account.CreatedAt,
		&account.PairID,
		&account.PartnerName,
		&account.CredentialCount,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Account{}, ErrNotFound
	}
	return account, err
}

func (s *Store) ListCredentials(ctx context.Context, accountID uuid.UUID) ([]CredentialRecord, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT credential_id, label, created_at, last_used_at
		FROM webauthn_credentials
		WHERE account_id = $1 AND revoked_at IS NULL
		ORDER BY created_at DESC`,
		accountID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var records []CredentialRecord
	for rows.Next() {
		var record CredentialRecord
		if err := rows.Scan(&record.ID, &record.Label, &record.CreatedAt, &record.LastUsedAt); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	return records, rows.Err()
}

func (s *Store) RevokeCredential(ctx context.Context, accountID uuid.UUID, credentialID []byte) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx, `
		UPDATE webauthn_credentials
		SET revoked_at = clock_timestamp()
		WHERE account_id = $1 AND credential_id = $2 AND revoked_at IS NULL`,
		accountID,
		credentialID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrNotFound
	}
	if _, err := tx.Exec(ctx, `
		UPDATE auth_sessions
		SET revoked_at = COALESCE(revoked_at, clock_timestamp()),
		    revoke_reason = 'passkey_revoked'
		WHERE account_id = $1 AND credential_id = $2`,
		accountID,
		credentialID,
	); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ListSessions(ctx context.Context, accountID, currentID uuid.UUID) ([]AuthSessionRecord, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT s.id, s.device_install_id, d.name, d.platform,
		       s.created_at, s.last_seen_at, s.id = $2
		FROM auth_sessions s
		JOIN device_installs d ON d.id = s.device_install_id AND d.account_id = s.account_id
		WHERE s.account_id = $1 AND s.revoked_at IS NULL AND s.expires_at > clock_timestamp()
		ORDER BY s.last_seen_at DESC`,
		accountID,
		currentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var records []AuthSessionRecord
	for rows.Next() {
		var record AuthSessionRecord
		if err := rows.Scan(
			&record.ID,
			&record.InstallationID,
			&record.InstallationName,
			&record.Platform,
			&record.CreatedAt,
			&record.LastSeenAt,
			&record.Current,
		); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	return records, rows.Err()
}

func (s *Store) RevokeSession(ctx context.Context, accountID, sessionID uuid.UUID, reason string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE auth_sessions
		SET revoked_at = clock_timestamp(), revoke_reason = $3
		WHERE id = $1 AND account_id = $2 AND revoked_at IS NULL`,
		sessionID,
		accountID,
		reason,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) ListInstallations(ctx context.Context, accountID uuid.UUID) ([]InstallationRecord, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, name, platform, created_at, last_seen_at
		FROM device_installs
		WHERE account_id = $1 AND revoked_at IS NULL
		ORDER BY last_seen_at DESC`,
		accountID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var records []InstallationRecord
	for rows.Next() {
		var record InstallationRecord
		if err := rows.Scan(&record.ID, &record.Name, &record.Platform, &record.CreatedAt, &record.LastSeenAt); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	return records, rows.Err()
}

func (s *Store) RevokeInstallation(ctx context.Context, accountID, installationID uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	tag, err := tx.Exec(ctx, `
		UPDATE device_installs
		SET revoked_at = clock_timestamp()
		WHERE id = $1 AND account_id = $2 AND revoked_at IS NULL`,
		installationID,
		accountID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrNotFound
	}
	if _, err := tx.Exec(ctx, `
		UPDATE auth_sessions
		SET revoked_at = COALESCE(revoked_at, clock_timestamp()),
		    revoke_reason = 'installation_revoked'
		WHERE account_id = $1 AND device_install_id = $2`,
		accountID,
		installationID,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE push_devices SET revoked_at = COALESCE(revoked_at, clock_timestamp())
		WHERE account_id = $1 AND device_install_id = $2`,
		accountID,
		installationID,
	); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ReplaceRecoveryCodes(ctx context.Context, accountID uuid.UUID, hashes []string) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `DELETE FROM recovery_codes WHERE account_id = $1`, accountID); err != nil {
		return err
	}
	for position, hash := range hashes {
		if _, err := tx.Exec(ctx, `
			INSERT INTO recovery_codes (account_id, position, code_hash)
			VALUES ($1, $2, $3)`,
			accountID,
			position,
			hash,
		); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
