//go:build integration

package integration_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/descope/virtualwebauthn"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/joshspicer/along/server/internal/apperror"
	alongauth "github.com/joshspicer/along/server/internal/auth"
	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/domain"
	"github.com/joshspicer/along/server/internal/migrate"
	"github.com/joshspicer/along/server/internal/store"
)

const (
	testRPID   = "localhost"
	testOrigin = "https://localhost"
)

var migrateOnce sync.Once
var migrateErr error

type registeredAccount struct {
	result        alongauth.AuthResult
	authenticator virtualwebauthn.Authenticator
	credential    virtualwebauthn.Credential
	device        domain.DeviceInfo
}

func TestPasskeyTokensRecoveryAndRevocation(t *testing.T) {
	data, service := testServices(t)
	account := register(t, service, "Jamie", "Jamie's iPhone")

	claimed, err := service.ParseAccessToken(account.result.Tokens.AccessToken)
	if err != nil {
		t.Fatalf("parse access token: %v", err)
	}
	if _, err := data.ValidateAuthSession(context.Background(), claimed); err != nil {
		t.Fatalf("validate auth session: %v", err)
	}

	login := login(t, service, account)
	if login.Account.ID != account.result.Account.ID {
		t.Fatalf("login account = %s, want %s", login.Account.ID, account.result.Account.ID)
	}

	rotated, err := service.Refresh(context.Background(), login.Tokens.RefreshToken)
	if err != nil {
		t.Fatalf("rotate refresh token: %v", err)
	}
	_, err = service.Refresh(context.Background(), login.Tokens.RefreshToken)
	if code := appCode(err); code != "refresh_reuse_detected" {
		t.Fatalf("refresh reuse code = %q, want refresh_reuse_detected (error %v)", code, err)
	}
	if _, err := service.Refresh(context.Background(), rotated.Tokens.RefreshToken); err == nil {
		t.Fatal("replacement refresh token survived family reuse")
	}
	loginClaimed, err := service.ParseAccessToken(login.Tokens.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := data.ValidateAuthSession(context.Background(), loginClaimed); err == nil {
		t.Fatal("session survived refresh-token reuse")
	}

	recoveryDevice := domain.DeviceInfo{
		ID:       uuid.New(),
		Platform: "ios",
		Name:     "Replacement iPhone",
	}
	recovered, err := service.Recover(
		context.Background(),
		account.result.RecoveryKit.RecoveryHandle,
		account.result.RecoveryKit.Codes[0],
		recoveryDevice,
	)
	if err != nil {
		t.Fatalf("recover account: %v", err)
	}
	if recovered.Account.ID != account.result.Account.ID {
		t.Fatal("recovery changed stable account identity")
	}
	if _, err := service.Recover(
		context.Background(),
		account.result.RecoveryKit.RecoveryHandle,
		account.result.RecoveryKit.Codes[0],
		domain.DeviceInfo{ID: uuid.New(), Platform: "ios", Name: "Replay"},
	); err == nil {
		t.Fatal("one-time recovery code was reused")
	}

	credentials, err := data.ListCredentials(context.Background(), account.result.Account.ID)
	if err != nil || len(credentials) != 1 {
		t.Fatalf("list credentials = %d, %v", len(credentials), err)
	}
	if err := data.RevokeCredential(context.Background(), account.result.Account.ID, credentials[0].ID); err != nil {
		t.Fatalf("revoke passkey: %v", err)
	}
	originalClaimed, err := service.ParseAccessToken(account.result.Tokens.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := data.ValidateAuthSession(context.Background(), originalClaimed); err == nil {
		t.Fatal("passkey-backed session survived passkey revocation")
	}

	if err := data.RevokeInstallation(
		context.Background(),
		account.result.Account.ID,
		recoveryDevice.ID,
	); err != nil {
		t.Fatalf("revoke installation: %v", err)
	}
	recoveryClaimed, err := service.ParseAccessToken(recovered.Tokens.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := data.ValidateAuthSession(context.Background(), recoveryClaimed); err == nil {
		t.Fatal("session survived installation revocation")
	}
}

func TestPairAuthorizationSessionConcurrencyAndReplay(t *testing.T) {
	data, service := testServices(t)
	jamie := register(t, service, "Jamie", "Jamie's iPhone")
	alex := register(t, service, "Alex", "Alex's Pixel")
	outsider := register(t, service, "Morgan", "Morgan's iPhone")

	rawInvite := "integration-pair-token"
	inviteHash := sha256.Sum256([]byte(rawInvite))
	if err := data.CreatePairInvite(
		context.Background(),
		jamie.result.Account.ID,
		uuid.New(),
		inviteHash[:],
		time.Now().Add(time.Hour),
	); err != nil {
		t.Fatal(err)
	}
	pair, err := data.AcceptPairInvite(context.Background(), alex.result.Account.ID, inviteHash[:])
	if err != nil {
		t.Fatalf("accept pair: %v", err)
	}
	jamieIdentity := validatedIdentity(t, data, service, jamie.result.Tokens.AccessToken)
	alexIdentity := validatedIdentity(t, data, service, alex.result.Tokens.AccessToken)
	if jamieIdentity.PairID == nil || alexIdentity.PairID == nil ||
		*jamieIdentity.PairID != pair.ID || *alexIdentity.PairID != pair.ID {
		t.Fatal("pair membership did not attach to stable accounts")
	}

	sessionID := uuid.New()
	idempotencyID := uuid.New()
	started, replayed, err := data.StartSession(
		context.Background(),
		jamieIdentity,
		idempotencyID,
		sessionID,
	)
	if err != nil || replayed {
		t.Fatalf("start session: replayed=%v err=%v", replayed, err)
	}
	replayedSession, replayed, err := data.StartSession(
		context.Background(),
		jamieIdentity,
		idempotencyID,
		sessionID,
	)
	if err != nil || !replayed || replayedSession.ID != started.ID {
		t.Fatalf("idempotent replay: replayed=%v err=%v", replayed, err)
	}

	joined, _, err := data.JoinSession(
		context.Background(),
		alexIdentity,
		sessionID,
		uuid.New(),
		started.Version,
	)
	if err != nil {
		t.Fatalf("join session: %v", err)
	}
	if !joined.StartedAt.Equal(started.StartedAt) || !joined.EndsAt.Equal(started.EndsAt) {
		t.Fatal("joining reset the authoritative clock")
	}
	if joined.State != domain.SessionTogether || len(joined.Participants) != 2 {
		t.Fatalf("joined session = state %s participants %d", joined.State, len(joined.Participants))
	}

	paused, _, err := data.TransitionSession(
		context.Background(),
		jamieIdentity,
		sessionID,
		uuid.New(),
		joined.Version,
		domain.ActionPause,
	)
	if err != nil || paused.State != domain.SessionPaused {
		t.Fatalf("pause session: state=%s err=%v", paused.State, err)
	}
	if _, _, err := data.TransitionSession(
		context.Background(),
		alexIdentity,
		sessionID,
		uuid.New(),
		joined.Version,
		domain.ActionComplete,
	); !errors.Is(err, store.ErrVersion) {
		t.Fatalf("stale expected version returned %v", err)
	}
	resumed, _, err := data.TransitionSession(
		context.Background(),
		alexIdentity,
		sessionID,
		uuid.New(),
		paused.Version,
		domain.ActionResume,
	)
	if err != nil || resumed.State != domain.SessionTogether || !resumed.EndsAt.After(joined.EndsAt) {
		t.Fatalf("resume session: %#v err=%v", resumed, err)
	}
	if _, _, err := data.AddCheer(
		context.Background(),
		jamieIdentity,
		sessionID,
		uuid.New(),
	); err != nil {
		t.Fatalf("add cheer: %v", err)
	}
	if _, _, err := data.AddNote(
		context.Background(),
		alexIdentity,
		sessionID,
		uuid.New(),
		"Glad you joined.",
	); err != nil {
		t.Fatalf("add note: %v", err)
	}
	completed, _, err := data.TransitionSession(
		context.Background(),
		jamieIdentity,
		sessionID,
		uuid.New(),
		resumed.Version,
		domain.ActionComplete,
	)
	if err != nil || completed.State != domain.SessionCompleted {
		t.Fatalf("complete session: state=%s err=%v", completed.State, err)
	}

	offlineID := uuid.New()
	offlineCompleted := time.Now().Add(-50 * time.Minute).UTC()
	if _, _, err := data.ImportSoloSession(
		context.Background(),
		jamieIdentity,
		uuid.New(),
		offlineID,
		offlineCompleted.Add(-10*time.Minute),
		offlineCompleted,
	); err != nil {
		t.Fatalf("import offline solo session: %v", err)
	}
	pausedOfflineID := uuid.New()
	pausedOfflineCompleted := time.Now().Add(-40 * time.Minute).UTC()
	if _, _, err := data.ImportSoloSession(
		context.Background(),
		jamieIdentity,
		uuid.New(),
		pausedOfflineID,
		pausedOfflineCompleted.Add(-2*time.Hour),
		pausedOfflineCompleted,
	); err != nil {
		t.Fatalf("import paused offline solo session: %v", err)
	}
	history, err := data.SessionHistory(context.Background(), jamieIdentity, nil, 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(history) != 3 ||
		history[0].ID != sessionID ||
		history[1].ID != pausedOfflineID ||
		history[2].ID != offlineID {
		t.Fatalf("history order = %#v", sessionIDs(history))
	}
	events, cursor, err := data.PairEvents(context.Background(), alexIdentity, 0, 100)
	if err != nil || len(events) < 8 || cursor == 0 {
		t.Fatalf("event replay len=%d cursor=%d err=%v", len(events), cursor, err)
	}

	outsiderIdentity := validatedIdentity(t, data, service, outsider.result.Tokens.AccessToken)
	outsiderIdentity.PairID = &pair.ID
	if _, _, err := data.StartSession(
		context.Background(),
		outsiderIdentity,
		uuid.New(),
		uuid.New(),
	); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("outsider authorization returned %v", err)
	}
	if _, err := data.Pool().Exec(context.Background(), `
		UPDATE pair_events SET event_type = 'tampered' WHERE pair_id = $1`,
		pair.ID,
	); err == nil {
		t.Fatal("append-only event log accepted an update")
	}
}

func testServices(t *testing.T) (*store.Store, *alongauth.Service) {
	t.Helper()
	databaseURL := os.Getenv("INTEGRATION_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("INTEGRATION_DATABASE_URL is not set")
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	migrateOnce.Do(func() {
		conn, err := pgx.Connect(context.Background(), databaseURL)
		if err != nil {
			migrateErr = err
			return
		}
		defer conn.Close(context.Background())
		migrateErr = migrate.Up(context.Background(), conn, logger)
	})
	if migrateErr != nil {
		t.Fatalf("migrate database: %v", migrateErr)
	}
	data, err := store.Open(context.Background(), databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(data.Close)
	if _, err := data.Pool().Exec(context.Background(), `TRUNCATE accounts RESTART IDENTITY CASCADE`); err != nil {
		t.Fatalf("reset database: %v", err)
	}
	cfg := config.Config{
		DatabaseURL:       databaseURL,
		WebAuthnRPID:      testRPID,
		WebAuthnRPOrigins: []string{testOrigin},
		JWTSigningKey:     []byte("0123456789abcdef0123456789abcdef"),
		AccessTokenTTL:    10 * time.Minute,
		RefreshTokenTTL:   30 * 24 * time.Hour,
		ChallengeTTL:      5 * time.Minute,
	}
	service, err := alongauth.NewService(cfg, data)
	if err != nil {
		t.Fatal(err)
	}
	return data, service
}

func register(t *testing.T, service *alongauth.Service, displayName, deviceName string) registeredAccount {
	t.Helper()
	device := domain.DeviceInfo{ID: uuid.New(), Platform: "ios", Name: deviceName}
	options, err := service.BeginAccountRegistration(context.Background(), displayName)
	if err != nil {
		t.Fatalf("begin registration: %v", err)
	}
	optionsJSON, err := json.Marshal(options.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := virtualwebauthn.ParseAttestationOptions(string(optionsJSON))
	if err != nil {
		t.Fatalf("parse registration options: %v; json=%s", err, optionsJSON)
	}
	relyingParty := virtualwebauthn.RelyingParty{Name: "Along", ID: testRPID, Origin: testOrigin}
	authenticator := virtualwebauthn.NewAuthenticator()
	credential := virtualwebauthn.NewCredential(virtualwebauthn.KeyTypeEC2)
	response := virtualwebauthn.CreateAttestationResponse(relyingParty, authenticator, credential, *parsed)
	request := httptest.NewRequest(http.MethodPost, testOrigin+"/v1/auth/register/finish", strings.NewReader(response))
	request.Header.Set("Content-Type", "application/json")
	result, err := service.FinishAccountRegistration(
		context.Background(),
		options.ChallengeID,
		request,
		device,
		deviceName,
	)
	if err != nil {
		t.Fatalf("finish registration: %v", err)
	}
	if result.RecoveryKit == nil || len(result.RecoveryKit.Codes) != 10 {
		t.Fatal("registration did not return a one-time recovery kit")
	}
	replay := httptest.NewRequest(http.MethodPost, testOrigin, strings.NewReader(response))
	if _, err := service.FinishAccountRegistration(
		context.Background(),
		options.ChallengeID,
		replay,
		device,
		deviceName,
	); appCode(err) != "ceremony_expired" {
		t.Fatalf("registration challenge replay error = %v", err)
	}
	authenticator.Options.UserHandle = []byte(parsed.UserID)
	authenticator.AddCredential(credential)
	return registeredAccount{
		result:        result,
		authenticator: authenticator,
		credential:    credential,
		device:        device,
	}
}

func login(t *testing.T, service *alongauth.Service, account registeredAccount) alongauth.AuthResult {
	t.Helper()
	options, err := service.BeginLogin(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	optionsJSON, err := json.Marshal(options.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := virtualwebauthn.ParseAssertionOptions(string(optionsJSON))
	if err != nil {
		t.Fatalf("parse login options: %v; json=%s", err, optionsJSON)
	}
	response := virtualwebauthn.CreateAssertionResponse(
		virtualwebauthn.RelyingParty{Name: "Along", ID: testRPID, Origin: testOrigin},
		account.authenticator,
		account.credential,
		*parsed,
	)
	request := httptest.NewRequest(http.MethodPost, testOrigin+"/v1/auth/login/finish", strings.NewReader(response))
	request.Header.Set("Content-Type", "application/json")
	result, err := service.FinishLogin(
		context.Background(),
		options.ChallengeID,
		request,
		domain.DeviceInfo{ID: uuid.New(), Platform: "ios", Name: "Login device"},
	)
	if err != nil {
		t.Fatalf("finish login: %v", err)
	}
	return result
}

func validatedIdentity(
	t *testing.T,
	data *store.Store,
	service *alongauth.Service,
	accessToken string,
) domain.AuthIdentity {
	t.Helper()
	claimed, err := service.ParseAccessToken(accessToken)
	if err != nil {
		t.Fatal(err)
	}
	validated, err := data.ValidateAuthSession(context.Background(), claimed)
	if err != nil {
		t.Fatal(err)
	}
	return validated
}

func appCode(err error) string {
	var appError *apperror.Error
	if errors.As(err, &appError) {
		return appError.Code
	}
	return ""
}

func sessionIDs(sessions []domain.FocusSession) []uuid.UUID {
	ids := make([]uuid.UUID, len(sessions))
	for index := range sessions {
		ids[index] = sessions[index].ID
	}
	return ids
}
