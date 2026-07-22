package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type Account struct {
	ID              uuid.UUID  `json:"id"`
	DisplayName     string     `json:"display_name"`
	RecoveryHandle  string     `json:"recovery_handle"`
	WebAuthnUserID  []byte     `json:"-"`
	Status          string     `json:"status"`
	CreatedAt       time.Time  `json:"created_at"`
	PairID          *uuid.UUID `json:"pair_id,omitempty"`
	PartnerName     string     `json:"partner_name,omitempty"`
	CredentialCount int        `json:"credential_count"`
	InstallationID  *uuid.UUID `json:"installation_id,omitempty"`
}

type AuthIdentity struct {
	AccountID      uuid.UUID
	SessionID      uuid.UUID
	InstallationID uuid.UUID
	PairID         *uuid.UUID
	DisplayName    string
}

type DeviceInfo struct {
	ID       uuid.UUID
	Platform string
	Name     string
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	TokenType    string    `json:"token_type"`
	ExpiresIn    int64     `json:"expires_in"`
	ExpiresAt    time.Time `json:"expires_at"`
	RefreshToken string    `json:"refresh_token"`
}

type RecoveryKit struct {
	AccountID      uuid.UUID `json:"account_id"`
	RecoveryHandle string    `json:"recovery_handle"`
	Codes          []string  `json:"codes"`
}

type SessionState string

const (
	SessionOpen      SessionState = "open"
	SessionTogether  SessionState = "together"
	SessionPaused    SessionState = "paused"
	SessionCompleted SessionState = "completed"
	SessionCancelled SessionState = "cancelled"
	SessionExpired   SessionState = "expired"
)

func (s SessionState) Terminal() bool {
	return s == SessionCompleted || s == SessionCancelled || s == SessionExpired
}

type FocusSession struct {
	ID              uuid.UUID     `json:"id"`
	PairID          uuid.UUID     `json:"pair_id"`
	StartedBy       uuid.UUID     `json:"started_by"`
	State           SessionState  `json:"state"`
	PauseOrigin     *SessionState `json:"pause_origin,omitempty"`
	DurationSeconds int           `json:"duration_seconds"`
	StartedAt       time.Time     `json:"started_at"`
	EndsAt          time.Time     `json:"ends_at"`
	PausedAt        *time.Time    `json:"paused_at,omitempty"`
	CompletedAt     *time.Time    `json:"completed_at,omitempty"`
	CancelledAt     *time.Time    `json:"cancelled_at,omitempty"`
	Version         int64         `json:"version"`
	OfflineOrigin   bool          `json:"offline_origin"`
	Participants    []Participant `json:"participants"`
	Notes           []SessionNote `json:"notes,omitempty"`
}

type Participant struct {
	AccountID   uuid.UUID `json:"account_id"`
	DisplayName string    `json:"display_name"`
	JoinedAt    time.Time `json:"joined_at"`
}

type SessionNote struct {
	ID          uuid.UUID `json:"id"`
	AccountID   uuid.UUID `json:"account_id"`
	DisplayName string    `json:"display_name"`
	Body        string    `json:"body"`
	CreatedAt   time.Time `json:"created_at"`
}

type PairEvent struct {
	Cursor    int64           `json:"cursor"`
	PairID    uuid.UUID       `json:"pair_id"`
	Type      string          `json:"type"`
	EntityID  *uuid.UUID      `json:"entity_id,omitempty"`
	ActorID   *uuid.UUID      `json:"actor_id,omitempty"`
	Payload   json.RawMessage `json:"payload"`
	CreatedAt time.Time       `json:"created_at"`
}

type PairInvite struct {
	ID        uuid.UUID `json:"id"`
	URL       string    `json:"url"`
	ExpiresAt time.Time `json:"expires_at"`
}

type PairSummary struct {
	ID          uuid.UUID `json:"id"`
	PartnerID   uuid.UUID `json:"partner_id"`
	PartnerName string    `json:"partner_name"`
	CreatedAt   time.Time `json:"created_at"`
}

type SyncCommand struct {
	ID              uuid.UUID       `json:"id"`
	Type            string          `json:"type"`
	EntityID        *uuid.UUID      `json:"entity_id,omitempty"`
	ExpectedVersion *int64          `json:"expected_version,omitempty"`
	Payload         json.RawMessage `json:"payload,omitempty"`
}

type SyncCommandResult struct {
	ID       uuid.UUID       `json:"id"`
	Applied  bool            `json:"applied"`
	Resource json.RawMessage `json:"resource,omitempty"`
	Error    *SyncError      `json:"error,omitempty"`
}

type SyncError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
