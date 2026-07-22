-- +along Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE accounts (
    id uuid PRIMARY KEY,
    webauthn_user_handle bytea NOT NULL UNIQUE,
    display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 80),
    recovery_handle text NOT NULL UNIQUE,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'deleted')),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    activated_at timestamptz,
    deleted_at timestamptz
);

CREATE TABLE webauthn_credentials (
    credential_id bytea PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    credential jsonb NOT NULL,
    label text NOT NULL DEFAULT 'Passkey' CHECK (char_length(label) BETWEEN 1 AND 80),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    last_used_at timestamptz,
    revoked_at timestamptz
);
CREATE INDEX webauthn_credentials_account_idx ON webauthn_credentials(account_id) WHERE revoked_at IS NULL;

CREATE TABLE auth_challenges (
    id uuid PRIMARY KEY,
    account_id uuid REFERENCES accounts(id) ON DELETE CASCADE,
    purpose text NOT NULL CHECK (purpose IN ('register_account', 'login', 'add_passkey')),
    session_data jsonb NOT NULL,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX auth_challenges_expiry_idx ON auth_challenges(expires_at) WHERE consumed_at IS NULL;

CREATE TABLE recovery_codes (
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    position smallint NOT NULL,
    code_hash text NOT NULL,
    used_at timestamptz,
    PRIMARY KEY (account_id, position)
);

CREATE TABLE device_installs (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    platform text NOT NULL CHECK (platform IN ('ios', 'android')),
    name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    revoked_at timestamptz,
    UNIQUE (id, account_id)
);
CREATE INDEX device_installs_account_idx ON device_installs(account_id) WHERE revoked_at IS NULL;

CREATE TABLE auth_sessions (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    device_install_id uuid NOT NULL,
    credential_id bytea REFERENCES webauthn_credentials(credential_id),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    revoked_at timestamptz,
    revoke_reason text,
    FOREIGN KEY (device_install_id, account_id) REFERENCES device_installs(id, account_id)
);
CREATE INDEX auth_sessions_active_idx ON auth_sessions(account_id, id) WHERE revoked_at IS NULL;

CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    auth_session_id uuid NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
    parent_id uuid REFERENCES refresh_tokens(id),
    token_hash bytea NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    replacement_id uuid,
    revoked_at timestamptz,
    UNIQUE (family_id, id)
);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens(family_id);

CREATE TABLE pairs (
    id uuid PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    dissolved_at timestamptz
);

CREATE TABLE pair_members (
    pair_id uuid NOT NULL REFERENCES pairs(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    joined_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (pair_id, account_id)
);
CREATE UNIQUE INDEX one_active_pair_per_account_idx ON pair_members(account_id);

CREATE TABLE pair_invites (
    id uuid PRIMARY KEY,
    created_by uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    token_hash bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    accepted_by uuid REFERENCES accounts(id),
    accepted_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX pair_invites_creator_idx ON pair_invites(created_by) WHERE accepted_at IS NULL AND revoked_at IS NULL;

CREATE TABLE focus_sessions (
    id uuid PRIMARY KEY,
    pair_id uuid NOT NULL REFERENCES pairs(id) ON DELETE CASCADE,
    started_by uuid NOT NULL REFERENCES accounts(id),
    state text NOT NULL CHECK (state IN ('open', 'together', 'paused', 'completed', 'cancelled', 'expired')),
    pause_origin text CHECK (pause_origin IN ('open', 'together')),
    duration_seconds integer NOT NULL DEFAULT 1500 CHECK (duration_seconds = 1500),
    started_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    paused_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    offline_origin boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE UNIQUE INDEX one_active_session_per_pair_idx
    ON focus_sessions(pair_id)
    WHERE state IN ('open', 'together', 'paused');
CREATE INDEX focus_sessions_history_idx ON focus_sessions(pair_id, completed_at DESC)
    WHERE state = 'completed';

CREATE TABLE session_members (
    session_id uuid NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id),
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (session_id, account_id)
);

CREATE TABLE session_notes (
    id uuid PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id),
    body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 120),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE reactions (
    id uuid PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id),
    kind text NOT NULL CHECK (kind = 'cheer'),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX reactions_cooldown_idx ON reactions(session_id, account_id, created_at DESC);

CREATE TABLE idempotency_keys (
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    key uuid NOT NULL,
    operation text NOT NULL,
    response_status integer NOT NULL,
    response_body jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    PRIMARY KEY (account_id, key)
);
CREATE INDEX idempotency_expiry_idx ON idempotency_keys(expires_at);

CREATE TABLE pair_events (
    cursor bigserial PRIMARY KEY,
    pair_id uuid NOT NULL REFERENCES pairs(id) ON DELETE CASCADE,
    event_type text NOT NULL,
    entity_id uuid,
    actor_id uuid REFERENCES accounts(id),
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX pair_events_replay_idx ON pair_events(pair_id, cursor);

CREATE TABLE push_devices (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    device_install_id uuid NOT NULL REFERENCES device_installs(id) ON DELETE CASCADE,
    token_hash bytea NOT NULL UNIQUE,
    token_ciphertext bytea NOT NULL,
    environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
    topic text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    revoked_at timestamptz
);
CREATE INDEX push_devices_account_idx ON push_devices(account_id) WHERE revoked_at IS NULL;

CREATE TABLE notification_jobs (
    id uuid PRIMARY KEY,
    pair_id uuid NOT NULL REFERENCES pairs(id) ON DELETE CASCADE,
    recipient_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    push_device_id uuid NOT NULL REFERENCES push_devices(id) ON DELETE CASCADE,
    event_cursor bigint REFERENCES pair_events(cursor),
    kind text NOT NULL CHECK (kind IN ('focus_started', 'partner_note')),
    payload jsonb NOT NULL,
    attempts integer NOT NULL DEFAULT 0,
    available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    locked_until timestamptz,
    sent_at timestamptz,
    failed_at timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX notification_jobs_ready_idx
    ON notification_jobs(available_at, created_at)
    WHERE sent_at IS NULL AND failed_at IS NULL;
CREATE UNIQUE INDEX notification_jobs_event_device_idx
    ON notification_jobs(event_cursor, push_device_id, kind);

CREATE OR REPLACE FUNCTION reject_pair_event_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'pair_events is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pair_events_no_update
BEFORE UPDATE OR DELETE ON pair_events
FOR EACH ROW EXECUTE FUNCTION reject_pair_event_mutation();

-- +along Down
DROP TRIGGER IF EXISTS pair_events_no_update ON pair_events;
DROP FUNCTION IF EXISTS reject_pair_event_mutation();
DROP TABLE IF EXISTS notification_jobs;
DROP TABLE IF EXISTS push_devices;
DROP TABLE IF EXISTS pair_events;
DROP TABLE IF EXISTS idempotency_keys;
DROP TABLE IF EXISTS reactions;
DROP TABLE IF EXISTS session_notes;
DROP TABLE IF EXISTS session_members;
DROP TABLE IF EXISTS focus_sessions;
DROP TABLE IF EXISTS pair_invites;
DROP TABLE IF EXISTS pair_members;
DROP TABLE IF EXISTS pairs;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS auth_sessions;
DROP TABLE IF EXISTS device_installs;
DROP TABLE IF EXISTS recovery_codes;
DROP TABLE IF EXISTS auth_challenges;
DROP TABLE IF EXISTS webauthn_credentials;
DROP TABLE IF EXISTS accounts;
