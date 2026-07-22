package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/joshspicer/along/server/internal/domain"
)

type commandResponse struct {
	Session domain.FocusSession `json:"session"`
}

type NoteResponse struct {
	Note domain.SessionNote `json:"note"`
}

type CheerResponse struct {
	ID        uuid.UUID `json:"id"`
	CreatedAt time.Time `json:"created_at"`
}

type dbQuerier interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}

func (s *Store) CreatePairInvite(
	ctx context.Context,
	accountID, inviteID uuid.UUID,
	tokenHash []byte,
	expiresAt time.Time,
) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var paired bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM pair_members WHERE account_id = $1)`,
		accountID,
	).Scan(&paired); err != nil {
		return err
	}
	if paired {
		return ErrAlreadyPaired
	}
	if _, err := tx.Exec(ctx, `
		UPDATE pair_invites
		SET revoked_at = clock_timestamp()
		WHERE created_by = $1 AND accepted_at IS NULL AND revoked_at IS NULL`,
		accountID,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO pair_invites (id, created_by, token_hash, expires_at)
		VALUES ($1, $2, $3, $4)`,
		inviteID,
		accountID,
		tokenHash,
		expiresAt,
	); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) AcceptPairInvite(
	ctx context.Context,
	accountID uuid.UUID,
	tokenHash []byte,
) (domain.PairSummary, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.PairSummary{}, err
	}
	defer tx.Rollback(ctx)

	var inviteID, creatorID uuid.UUID
	err = tx.QueryRow(ctx, `
		SELECT id, created_by
		FROM pair_invites
		WHERE token_hash = $1
		  AND expires_at > clock_timestamp()
		  AND accepted_at IS NULL
		  AND revoked_at IS NULL
		FOR UPDATE`,
		tokenHash,
	).Scan(&inviteID, &creatorID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PairSummary{}, ErrNotFound
	}
	if err != nil {
		return domain.PairSummary{}, err
	}
	if creatorID == accountID {
		return domain.PairSummary{}, ErrConflict
	}
	var membershipCount int
	if err := tx.QueryRow(ctx, `
		SELECT count(*) FROM pair_members WHERE account_id IN ($1, $2)`,
		creatorID,
		accountID,
	).Scan(&membershipCount); err != nil {
		return domain.PairSummary{}, err
	}
	if membershipCount > 0 {
		return domain.PairSummary{}, ErrAlreadyPaired
	}
	pairID := uuid.New()
	var partnerName string
	if err := tx.QueryRow(ctx,
		`SELECT display_name FROM accounts WHERE id = $1 AND status = 'active' FOR SHARE`,
		creatorID,
	).Scan(&partnerName); err != nil {
		return domain.PairSummary{}, ErrNotFound
	}
	var createdAt time.Time
	if err := tx.QueryRow(ctx, `
		INSERT INTO pairs (id) VALUES ($1) RETURNING created_at`,
		pairID,
	).Scan(&createdAt); err != nil {
		return domain.PairSummary{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO pair_members (pair_id, account_id)
		VALUES ($1, $2), ($1, $3)`,
		pairID,
		creatorID,
		accountID,
	); err != nil {
		return domain.PairSummary{}, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE pair_invites
		SET accepted_by = $2, accepted_at = clock_timestamp()
		WHERE id = $1`,
		inviteID,
		accountID,
	); err != nil {
		return domain.PairSummary{}, err
	}
	if _, err := appendPairEvent(ctx, tx, pairID, "pair.created", &pairID, &accountID, map[string]any{
		"pair_id": pairID,
		"members": []uuid.UUID{creatorID, accountID},
	}); err != nil {
		return domain.PairSummary{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PairSummary{}, err
	}
	return domain.PairSummary{
		ID:          pairID,
		PartnerID:   creatorID,
		PartnerName: partnerName,
		CreatedAt:   createdAt,
	}, nil
}

func (s *Store) Pair(ctx context.Context, accountID uuid.UUID) (domain.PairSummary, error) {
	var pair domain.PairSummary
	err := s.pool.QueryRow(ctx, `
		SELECT p.id, other.account_id, partner.display_name, p.created_at
		FROM pair_members mine
		JOIN pairs p ON p.id = mine.pair_id AND p.dissolved_at IS NULL
		JOIN pair_members other ON other.pair_id = mine.pair_id AND other.account_id <> mine.account_id
		JOIN accounts partner ON partner.id = other.account_id
		WHERE mine.account_id = $1`,
		accountID,
	).Scan(&pair.ID, &pair.PartnerID, &pair.PartnerName, &pair.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PairSummary{}, ErrNotFound
	}
	return pair, err
}

func (s *Store) StartSession(
	ctx context.Context,
	identity domain.AuthIdentity,
	idempotencyID, sessionID uuid.UUID,
) (domain.FocusSession, bool, error) {
	if identity.PairID == nil {
		return domain.FocusSession{}, false, ErrNotFound
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	defer tx.Rollback(ctx)
	if cached, ok, err := idempotentSession(ctx, tx, identity.AccountID, idempotencyID, "session.start"); err != nil || ok {
		return cached, ok, err
	}
	if err := requirePairMember(ctx, tx, *identity.PairID, identity.AccountID); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := s.completeElapsedSession(ctx, tx, *identity.PairID); err != nil {
		return domain.FocusSession{}, false, err
	}
	var active bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM focus_sessions
			WHERE pair_id = $1 AND state IN ('open', 'together', 'paused')
		)`,
		*identity.PairID,
	).Scan(&active); err != nil {
		return domain.FocusSession{}, false, err
	}
	if active {
		return domain.FocusSession{}, false, ErrActiveSession
	}
	now := s.now().UTC()
	_, err = tx.Exec(ctx, `
		INSERT INTO focus_sessions
		  (id, pair_id, started_by, state, started_at, ends_at)
		VALUES ($1, $2, $3, 'open', $4, $5)`,
		sessionID,
		*identity.PairID,
		identity.AccountID,
		now,
		now.Add(25*time.Minute),
	)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO session_members (session_id, account_id, joined_at)
		VALUES ($1, $2, $3)`,
		sessionID,
		identity.AccountID,
		now,
	)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	session, err := readSession(ctx, tx, sessionID)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	cursor, err := appendPairEvent(ctx, tx, *identity.PairID, "session.started", &sessionID, &identity.AccountID, session)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := enqueuePartnerNotification(ctx, tx, *identity.PairID, identity.AccountID, cursor, "focus_started", map[string]any{
		"title":     "Along",
		"body":      "Your partner started a focus.",
		"deep_link": "along:///focus",
	}); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := saveIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.start", commandResponse{Session: session}); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.FocusSession{}, false, err
	}
	return session, false, nil
}

func (s *Store) ImportSoloSession(
	ctx context.Context,
	identity domain.AuthIdentity,
	idempotencyID, sessionID uuid.UUID,
	startedAt, completedAt time.Time,
) (domain.FocusSession, bool, error) {
	if identity.PairID == nil {
		return domain.FocusSession{}, false, ErrNotFound
	}
	if startedAt.After(completedAt) || completedAt.Sub(startedAt) > 24*time.Hour ||
		completedAt.After(s.now().Add(2*time.Minute)) {
		return domain.FocusSession{}, false, ErrConflict
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	defer tx.Rollback(ctx)
	if cached, ok, err := idempotentSession(ctx, tx, identity.AccountID, idempotencyID, "session.import_solo"); err != nil || ok {
		return cached, ok, err
	}
	if err := requirePairMember(ctx, tx, *identity.PairID, identity.AccountID); err != nil {
		return domain.FocusSession{}, false, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO focus_sessions
		  (id, pair_id, started_by, state, started_at, ends_at, completed_at, offline_origin)
		VALUES ($1, $2, $3, 'completed', $4, $5, $5, true)`,
		sessionID,
		*identity.PairID,
		identity.AccountID,
		startedAt.UTC(),
		completedAt.UTC(),
	)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO session_members (session_id, account_id, joined_at)
		VALUES ($1, $2, $3)`,
		sessionID,
		identity.AccountID,
		startedAt.UTC(),
	)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	session, err := readSession(ctx, tx, sessionID)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	if _, err := appendPairEvent(ctx, tx, *identity.PairID, "session.completed", &sessionID, &identity.AccountID, session); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := saveIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.import_solo", commandResponse{Session: session}); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.FocusSession{}, false, err
	}
	return session, false, nil
}

func (s *Store) JoinSession(
	ctx context.Context,
	identity domain.AuthIdentity,
	sessionID, idempotencyID uuid.UUID,
	expectedVersion int64,
) (domain.FocusSession, bool, error) {
	return s.transitionSession(ctx, identity, sessionID, idempotencyID, expectedVersion, domain.ActionJoin)
}

func (s *Store) TransitionSession(
	ctx context.Context,
	identity domain.AuthIdentity,
	sessionID, idempotencyID uuid.UUID,
	expectedVersion int64,
	action domain.SessionAction,
) (domain.FocusSession, bool, error) {
	return s.transitionSession(ctx, identity, sessionID, idempotencyID, expectedVersion, action)
}

func (s *Store) transitionSession(
	ctx context.Context,
	identity domain.AuthIdentity,
	sessionID, idempotencyID uuid.UUID,
	expectedVersion int64,
	action domain.SessionAction,
) (domain.FocusSession, bool, error) {
	if identity.PairID == nil {
		return domain.FocusSession{}, false, ErrNotFound
	}
	operation := "session." + string(action)
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	defer tx.Rollback(ctx)
	if cached, ok, err := idempotentSession(ctx, tx, identity.AccountID, idempotencyID, operation); err != nil || ok {
		return cached, ok, err
	}
	if err := requirePairMember(ctx, tx, *identity.PairID, identity.AccountID); err != nil {
		return domain.FocusSession{}, false, err
	}
	current, err := readSessionForUpdate(ctx, tx, sessionID, *identity.PairID)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	if current.Version != expectedVersion {
		return domain.FocusSession{}, false, ErrVersion
	}
	next, pauseOrigin, err := domain.NextState(current.State, current.PauseOrigin, action)
	if err != nil {
		return domain.FocusSession{}, false, ErrConflict
	}
	now := s.now().UTC()
	switch action {
	case domain.ActionJoin:
		if current.StartedBy == identity.AccountID || now.After(current.EndsAt) {
			return domain.FocusSession{}, false, ErrConflict
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO session_members (session_id, account_id, joined_at)
			VALUES ($1, $2, $3)`,
			sessionID,
			identity.AccountID,
			now,
		); err != nil {
			return domain.FocusSession{}, false, err
		}
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = $2, version = version + 1, updated_at = $3
			WHERE id = $1`,
			sessionID,
			next,
			now,
		)
	case domain.ActionPause:
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'paused', pause_origin = $2, paused_at = $3,
			    version = version + 1, updated_at = $3
			WHERE id = $1`,
			sessionID,
			pauseOrigin,
			now,
		)
	case domain.ActionResume:
		if current.PausedAt == nil {
			return domain.FocusSession{}, false, ErrConflict
		}
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = $2, pause_origin = NULL, paused_at = NULL,
			    ends_at = ends_at + ($3 - paused_at),
			    version = version + 1, updated_at = $3
			WHERE id = $1`,
			sessionID,
			next,
			now,
		)
	case domain.ActionComplete:
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'completed', pause_origin = NULL, paused_at = NULL,
			    completed_at = $2, version = version + 1, updated_at = $2
			WHERE id = $1`,
			sessionID,
			now,
		)
	case domain.ActionCancel:
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'cancelled', pause_origin = NULL, paused_at = NULL,
			    cancelled_at = $2, version = version + 1, updated_at = $2
			WHERE id = $1`,
			sessionID,
			now,
		)
	case domain.ActionExpire:
		_, err = tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'expired', pause_origin = NULL, paused_at = NULL,
			    version = version + 1, updated_at = $2
			WHERE id = $1`,
			sessionID,
			now,
		)
	}
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	session, err := readSession(ctx, tx, sessionID)
	if err != nil {
		return domain.FocusSession{}, false, err
	}
	eventType := operation
	if action == domain.ActionJoin {
		eventType = "session.joined"
	}
	if _, err := appendPairEvent(ctx, tx, *identity.PairID, eventType, &sessionID, &identity.AccountID, session); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := saveIdempotency(ctx, tx, identity.AccountID, idempotencyID, operation, commandResponse{Session: session}); err != nil {
		return domain.FocusSession{}, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.FocusSession{}, false, err
	}
	return session, false, nil
}

func (s *Store) AddNote(
	ctx context.Context,
	identity domain.AuthIdentity,
	sessionID, idempotencyID uuid.UUID,
	body string,
) (domain.SessionNote, bool, error) {
	if identity.PairID == nil {
		return domain.SessionNote{}, false, ErrNotFound
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return domain.SessionNote{}, false, err
	}
	defer tx.Rollback(ctx)
	var cached NoteResponse
	if ok, err := getIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.note", &cached); err != nil || ok {
		return cached.Note, ok, err
	}
	if err := requirePairMember(ctx, tx, *identity.PairID, identity.AccountID); err != nil {
		return domain.SessionNote{}, false, err
	}
	var exists bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM focus_sessions
			WHERE id = $1 AND pair_id = $2 AND state <> 'cancelled'
		)`,
		sessionID,
		*identity.PairID,
	).Scan(&exists); err != nil || !exists {
		if err != nil {
			return domain.SessionNote{}, false, err
		}
		return domain.SessionNote{}, false, ErrNotFound
	}
	note := domain.SessionNote{
		ID:          uuid.New(),
		AccountID:   identity.AccountID,
		DisplayName: identity.DisplayName,
		Body:        body,
	}
	if err := tx.QueryRow(ctx, `
		INSERT INTO session_notes (id, session_id, account_id, body)
		VALUES ($1, $2, $3, $4)
		RETURNING created_at`,
		note.ID,
		sessionID,
		identity.AccountID,
		body,
	).Scan(&note.CreatedAt); err != nil {
		return domain.SessionNote{}, false, err
	}
	cursor, err := appendPairEvent(ctx, tx, *identity.PairID, "session.note_added", &sessionID, &identity.AccountID, note)
	if err != nil {
		return domain.SessionNote{}, false, err
	}
	if err := enqueuePartnerNotification(ctx, tx, *identity.PairID, identity.AccountID, cursor, "partner_note", map[string]any{
		"title":     "Along",
		"body":      "Your partner left a note.",
		"deep_link": "along:///look-back",
	}); err != nil {
		return domain.SessionNote{}, false, err
	}
	if err := saveIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.note", NoteResponse{Note: note}); err != nil {
		return domain.SessionNote{}, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.SessionNote{}, false, err
	}
	return note, false, nil
}

func (s *Store) AddCheer(
	ctx context.Context,
	identity domain.AuthIdentity,
	sessionID, idempotencyID uuid.UUID,
) (CheerResponse, bool, error) {
	if identity.PairID == nil {
		return CheerResponse{}, false, ErrNotFound
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return CheerResponse{}, false, err
	}
	defer tx.Rollback(ctx)
	var cached CheerResponse
	if ok, err := getIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.cheer", &cached); err != nil || ok {
		return cached, ok, err
	}
	var state domain.SessionState
	if err := tx.QueryRow(ctx, `
		SELECT state FROM focus_sessions
		WHERE id = $1 AND pair_id = $2
		FOR UPDATE`,
		sessionID,
		*identity.PairID,
	).Scan(&state); errors.Is(err, pgx.ErrNoRows) {
		return CheerResponse{}, false, ErrNotFound
	} else if err != nil {
		return CheerResponse{}, false, err
	}
	if state != domain.SessionTogether && state != domain.SessionPaused {
		return CheerResponse{}, false, ErrConflict
	}
	var recent bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM reactions
			WHERE session_id = $1 AND account_id = $2
			  AND created_at > clock_timestamp() - interval '30 seconds'
		)`,
		sessionID,
		identity.AccountID,
	).Scan(&recent); err != nil {
		return CheerResponse{}, false, err
	}
	if recent {
		return CheerResponse{}, false, ErrCooldown
	}
	response := CheerResponse{ID: uuid.New()}
	if err := tx.QueryRow(ctx, `
		INSERT INTO reactions (id, session_id, account_id, kind)
		VALUES ($1, $2, $3, 'cheer')
		RETURNING created_at`,
		response.ID,
		sessionID,
		identity.AccountID,
	).Scan(&response.CreatedAt); err != nil {
		return CheerResponse{}, false, err
	}
	if _, err := appendPairEvent(ctx, tx, *identity.PairID, "session.cheered", &sessionID, &identity.AccountID, response); err != nil {
		return CheerResponse{}, false, err
	}
	if err := saveIdempotency(ctx, tx, identity.AccountID, idempotencyID, "session.cheer", response); err != nil {
		return CheerResponse{}, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CheerResponse{}, false, err
	}
	return response, false, nil
}

func (s *Store) CurrentSession(ctx context.Context, identity domain.AuthIdentity) (*domain.FocusSession, error) {
	if identity.PairID == nil {
		return nil, nil
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	if err := s.completeElapsedSession(ctx, tx, *identity.PairID); err != nil {
		return nil, err
	}
	var id uuid.UUID
	err = tx.QueryRow(ctx, `
		SELECT id FROM focus_sessions
		WHERE pair_id = $1 AND state IN ('open', 'together', 'paused')
		ORDER BY started_at DESC LIMIT 1`,
		*identity.PairID,
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	session, err := readSession(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &session, nil
}

func (s *Store) SessionHistory(ctx context.Context, identity domain.AuthIdentity, before *time.Time, limit int) ([]domain.FocusSession, error) {
	if identity.PairID == nil {
		return []domain.FocusSession{}, nil
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}
	cutoff := s.now().Add(time.Minute)
	if before != nil {
		cutoff = before.UTC()
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id
		FROM focus_sessions
		WHERE pair_id = $1 AND state = 'completed' AND completed_at < $2
		ORDER BY completed_at DESC, id DESC
		LIMIT $3`,
		*identity.PairID,
		cutoff,
		limit,
	)
	if err != nil {
		return nil, err
	}
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	sessions := make([]domain.FocusSession, 0, len(ids))
	for _, id := range ids {
		session, err := readSession(ctx, s.pool, id)
		if err != nil {
			return nil, err
		}
		sessions = append(sessions, session)
	}
	return sessions, nil
}

func (s *Store) PairEvents(ctx context.Context, identity domain.AuthIdentity, cursor int64, limit int) ([]domain.PairEvent, int64, error) {
	if identity.PairID == nil {
		return []domain.PairEvent{}, cursor, nil
	}
	if limit < 1 || limit > 500 {
		limit = 200
	}
	rows, err := s.pool.Query(ctx, `
		SELECT cursor, pair_id, event_type, entity_id, actor_id, payload, created_at
		FROM pair_events
		WHERE pair_id = $1 AND cursor > $2
		ORDER BY cursor
		LIMIT $3`,
		*identity.PairID,
		cursor,
		limit,
	)
	if err != nil {
		return nil, cursor, err
	}
	defer rows.Close()
	events := make([]domain.PairEvent, 0)
	next := cursor
	for rows.Next() {
		var event domain.PairEvent
		if err := rows.Scan(
			&event.Cursor,
			&event.PairID,
			&event.Type,
			&event.EntityID,
			&event.ActorID,
			&event.Payload,
			&event.CreatedAt,
		); err != nil {
			return nil, cursor, err
		}
		events = append(events, event)
		next = event.Cursor
	}
	return events, next, rows.Err()
}

func (s *Store) completeElapsedSession(ctx context.Context, tx pgx.Tx, pairID uuid.UUID) error {
	staleRows, err := tx.Query(ctx, `
		SELECT id
		FROM focus_sessions
		WHERE pair_id = $1
		  AND state = 'paused'
		  AND paused_at <= clock_timestamp() - interval '24 hours'
		FOR UPDATE`,
		pairID,
	)
	if err != nil {
		return err
	}
	var staleIDs []uuid.UUID
	for staleRows.Next() {
		var id uuid.UUID
		if err := staleRows.Scan(&id); err != nil {
			staleRows.Close()
			return err
		}
		staleIDs = append(staleIDs, id)
	}
	staleRows.Close()
	if err := staleRows.Err(); err != nil {
		return err
	}
	for _, id := range staleIDs {
		if _, err := tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'expired', pause_origin = NULL, paused_at = NULL,
			    version = version + 1, updated_at = clock_timestamp()
			WHERE id = $1`,
			id,
		); err != nil {
			return err
		}
		session, err := readSession(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := appendPairEvent(ctx, tx, pairID, "session.expired", &id, nil, session); err != nil {
			return err
		}
	}

	rows, err := tx.Query(ctx, `
		SELECT id, ends_at
		FROM focus_sessions
		WHERE pair_id = $1
		  AND state IN ('open', 'together')
		  AND ends_at <= clock_timestamp()
		FOR UPDATE`,
		pairID,
	)
	if err != nil {
		return err
	}
	type elapsed struct {
		id     uuid.UUID
		endsAt time.Time
	}
	var sessions []elapsed
	for rows.Next() {
		var item elapsed
		if err := rows.Scan(&item.id, &item.endsAt); err != nil {
			rows.Close()
			return err
		}
		sessions = append(sessions, item)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	for _, item := range sessions {
		if _, err := tx.Exec(ctx, `
			UPDATE focus_sessions
			SET state = 'completed', completed_at = $2,
			    version = version + 1, updated_at = clock_timestamp()
			WHERE id = $1`,
			item.id,
			item.endsAt,
		); err != nil {
			return err
		}
		session, err := readSession(ctx, tx, item.id)
		if err != nil {
			return err
		}
		if _, err := appendPairEvent(ctx, tx, pairID, "session.completed", &item.id, nil, session); err != nil {
			return err
		}
	}
	return nil
}

func readSessionForUpdate(ctx context.Context, tx pgx.Tx, id, pairID uuid.UUID) (domain.FocusSession, error) {
	var found uuid.UUID
	err := tx.QueryRow(ctx, `
		SELECT id FROM focus_sessions WHERE id = $1 AND pair_id = $2 FOR UPDATE`,
		id,
		pairID,
	).Scan(&found)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.FocusSession{}, ErrNotFound
	}
	if err != nil {
		return domain.FocusSession{}, err
	}
	return readSession(ctx, tx, found)
}

func readSession(ctx context.Context, db dbQuerier, id uuid.UUID) (domain.FocusSession, error) {
	var session domain.FocusSession
	var state string
	var pauseOrigin *string
	err := db.QueryRow(ctx, `
		SELECT id, pair_id, started_by, state, pause_origin, duration_seconds,
		       started_at, ends_at, paused_at, completed_at, cancelled_at,
		       version, offline_origin
		FROM focus_sessions
		WHERE id = $1`,
		id,
	).Scan(
		&session.ID,
		&session.PairID,
		&session.StartedBy,
		&state,
		&pauseOrigin,
		&session.DurationSeconds,
		&session.StartedAt,
		&session.EndsAt,
		&session.PausedAt,
		&session.CompletedAt,
		&session.CancelledAt,
		&session.Version,
		&session.OfflineOrigin,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.FocusSession{}, ErrNotFound
	}
	if err != nil {
		return domain.FocusSession{}, err
	}
	session.State = domain.SessionState(state)
	if pauseOrigin != nil {
		origin := domain.SessionState(*pauseOrigin)
		session.PauseOrigin = &origin
	}
	rows, err := db.Query(ctx, `
		SELECT m.account_id, a.display_name, m.joined_at
		FROM session_members m
		JOIN accounts a ON a.id = m.account_id
		WHERE m.session_id = $1
		ORDER BY m.joined_at`,
		id,
	)
	if err != nil {
		return domain.FocusSession{}, err
	}
	for rows.Next() {
		var participant domain.Participant
		if err := rows.Scan(&participant.AccountID, &participant.DisplayName, &participant.JoinedAt); err != nil {
			rows.Close()
			return domain.FocusSession{}, err
		}
		session.Participants = append(session.Participants, participant)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return domain.FocusSession{}, err
	}
	noteRows, err := db.Query(ctx, `
		SELECT n.id, n.account_id, a.display_name, n.body, n.created_at
		FROM session_notes n
		JOIN accounts a ON a.id = n.account_id
		WHERE n.session_id = $1
		ORDER BY n.created_at`,
		id,
	)
	if err != nil {
		return domain.FocusSession{}, err
	}
	for noteRows.Next() {
		var note domain.SessionNote
		if err := noteRows.Scan(&note.ID, &note.AccountID, &note.DisplayName, &note.Body, &note.CreatedAt); err != nil {
			noteRows.Close()
			return domain.FocusSession{}, err
		}
		session.Notes = append(session.Notes, note)
	}
	noteRows.Close()
	if err := noteRows.Err(); err != nil {
		return domain.FocusSession{}, err
	}
	return session, nil
}

func requirePairMember(ctx context.Context, tx pgx.Tx, pairID, accountID uuid.UUID) error {
	var exists bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM pair_members pm
			JOIN pairs p ON p.id = pm.pair_id AND p.dissolved_at IS NULL
			WHERE pm.pair_id = $1 AND pm.account_id = $2
		)`,
		pairID,
		accountID,
	).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return ErrNotFound
	}
	return nil
}

func appendPairEvent(
	ctx context.Context,
	tx pgx.Tx,
	pairID uuid.UUID,
	eventType string,
	entityID, actorID *uuid.UUID,
	payload any,
) (int64, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return 0, err
	}
	var cursor int64
	if err := tx.QueryRow(ctx, `
		INSERT INTO pair_events (pair_id, event_type, entity_id, actor_id, payload)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING cursor`,
		pairID,
		eventType,
		entityID,
		actorID,
		raw,
	).Scan(&cursor); err != nil {
		return 0, err
	}
	notification, err := json.Marshal(map[string]any{"pair_id": pairID, "cursor": cursor})
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(ctx, `SELECT pg_notify('pair_events', $1)`, string(notification)); err != nil {
		return 0, err
	}
	return cursor, nil
}

func enqueuePartnerNotification(
	ctx context.Context,
	tx pgx.Tx,
	pairID, actorID uuid.UUID,
	cursor int64,
	kind string,
	payload any,
) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO notification_jobs
		  (id, pair_id, recipient_account_id, push_device_id, event_cursor, kind, payload)
		SELECT gen_random_uuid(), $1, pm.account_id, d.id, $3, $4, $5
		FROM pair_members pm
		JOIN push_devices d ON d.account_id = pm.account_id AND d.revoked_at IS NULL
		WHERE pm.pair_id = $1 AND pm.account_id <> $2`,
		pairID,
		actorID,
		cursor,
		kind,
		raw,
	)
	return err
}

func getIdempotency(
	ctx context.Context,
	tx pgx.Tx,
	accountID, key uuid.UUID,
	operation string,
	destination any,
) (bool, error) {
	var storedOperation string
	var raw []byte
	err := tx.QueryRow(ctx, `
		SELECT operation, response_body
		FROM idempotency_keys
		WHERE account_id = $1 AND key = $2 AND expires_at > clock_timestamp()`,
		accountID,
		key,
	).Scan(&storedOperation, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if storedOperation != operation {
		return false, ErrConflict
	}
	if err := json.Unmarshal(raw, destination); err != nil {
		return false, fmt.Errorf("decode idempotent response: %w", err)
	}
	return true, nil
}

func idempotentSession(
	ctx context.Context,
	tx pgx.Tx,
	accountID, key uuid.UUID,
	operation string,
) (domain.FocusSession, bool, error) {
	var response commandResponse
	ok, err := getIdempotency(ctx, tx, accountID, key, operation, &response)
	return response.Session, ok, err
}

func saveIdempotency(
	ctx context.Context,
	tx pgx.Tx,
	accountID, key uuid.UUID,
	operation string,
	response any,
) error {
	raw, err := json.Marshal(response)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO idempotency_keys
		  (account_id, key, operation, response_status, response_body, expires_at)
		VALUES ($1, $2, $3, 200, $4, clock_timestamp() + interval '7 days')`,
		accountID,
		key,
		operation,
		raw,
	)
	return err
}
