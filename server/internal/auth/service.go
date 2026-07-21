package auth

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/apperror"
	"github.com/joshspicer/along/server/internal/config"
	"github.com/joshspicer/along/server/internal/domain"
	"github.com/joshspicer/along/server/internal/store"
)

const recoveryCodeCount = 10

type Service struct {
	store        *store.Store
	webAuthn     *webauthn.WebAuthn
	tokens       *TokenManager
	accessTTL    time.Duration
	refreshTTL   time.Duration
	challengeTTL time.Duration
	now          func() time.Time
}

type CeremonyOptions struct {
	ChallengeID uuid.UUID `json:"challenge_id"`
	PublicKey   any       `json:"publicKey"`
}

type AuthResult struct {
	Tokens      domain.TokenPair    `json:"tokens"`
	Account     domain.Account      `json:"account"`
	RecoveryKit *domain.RecoveryKit `json:"recovery_kit,omitempty"`
}

type webAuthnUser struct {
	account     store.WebAuthnAccount
	credentials []webauthn.Credential
}

func (u *webAuthnUser) WebAuthnID() []byte {
	return u.account.WebAuthnUserID
}

func (u *webAuthnUser) WebAuthnName() string {
	return u.account.DisplayName
}

func (u *webAuthnUser) WebAuthnDisplayName() string {
	return u.account.DisplayName
}

func (u *webAuthnUser) WebAuthnCredentials() []webauthn.Credential {
	return u.credentials
}

func NewService(cfg config.Config, data *store.Store) (*Service, error) {
	webAuthn, err := webauthn.New(&webauthn.Config{
		RPID:                  cfg.WebAuthnRPID,
		RPDisplayName:         "Along",
		RPOrigins:             cfg.WebAuthnRPOrigins,
		AttestationPreference: protocol.PreferNoAttestation,
		AuthenticatorSelection: protocol.AuthenticatorSelection{
			ResidentKey:      protocol.ResidentKeyRequirementRequired,
			UserVerification: protocol.VerificationRequired,
		},
	})
	if err != nil {
		return nil, fmt.Errorf("configure WebAuthn: %w", err)
	}
	return &Service{
		store:        data,
		webAuthn:     webAuthn,
		tokens:       NewTokenManager(cfg.JWTSigningKey, cfg.AccessTokenTTL),
		accessTTL:    cfg.AccessTokenTTL,
		refreshTTL:   cfg.RefreshTokenTTL,
		challengeTTL: cfg.ChallengeTTL,
		now:          time.Now,
	}, nil
}

func (s *Service) BeginAccountRegistration(ctx context.Context, displayName string) (CeremonyOptions, error) {
	displayName = strings.TrimSpace(displayName)
	if len([]rune(displayName)) < 1 || len([]rune(displayName)) > 80 {
		return CeremonyOptions{}, apperror.New(http.StatusUnprocessableEntity, "invalid_display_name", "Use a name between 1 and 80 characters.")
	}
	userHandle := make([]byte, 64)
	if _, err := rand.Read(userHandle); err != nil {
		return CeremonyOptions{}, fmt.Errorf("generate WebAuthn user handle: %w", err)
	}
	recoveryHandle, err := RecoveryHandle()
	if err != nil {
		return CeremonyOptions{}, fmt.Errorf("generate recovery handle: %w", err)
	}
	account, err := s.store.CreatePendingAccount(ctx, uuid.New(), userHandle, displayName, recoveryHandle)
	if err != nil {
		return CeremonyOptions{}, err
	}
	user := &webAuthnUser{account: store.WebAuthnAccount{Account: account}}
	options, session, err := s.webAuthn.BeginRegistration(
		user,
		webauthn.WithAuthenticatorSelection(protocol.AuthenticatorSelection{
			ResidentKey:      protocol.ResidentKeyRequirementRequired,
			UserVerification: protocol.VerificationRequired,
		}),
	)
	if err != nil {
		_ = s.store.DeletePendingAccount(ctx, account.ID)
		return CeremonyOptions{}, fmt.Errorf("begin registration: %w", err)
	}
	sessionJSON, err := json.Marshal(session)
	if err != nil {
		_ = s.store.DeletePendingAccount(ctx, account.ID)
		return CeremonyOptions{}, err
	}
	challengeID := uuid.New()
	if err := s.store.CreateChallenge(ctx, challengeID, &account.ID, "register_account", sessionJSON, s.now().Add(s.challengeTTL)); err != nil {
		_ = s.store.DeletePendingAccount(ctx, account.ID)
		return CeremonyOptions{}, err
	}
	return CeremonyOptions{ChallengeID: challengeID, PublicKey: options.Response}, nil
}

func (s *Service) FinishAccountRegistration(
	ctx context.Context,
	challengeID uuid.UUID,
	request *http.Request,
	device domain.DeviceInfo,
	label string,
) (AuthResult, error) {
	challenge, err := s.store.ConsumeChallenge(ctx, challengeID, "register_account")
	if err != nil || challenge.AccountID == nil {
		return AuthResult{}, apperror.New(http.StatusGone, "ceremony_expired", "Start the passkey setup again.")
	}
	account, err := s.store.GetWebAuthnAccountByID(ctx, *challenge.AccountID)
	if err != nil {
		return AuthResult{}, err
	}
	user, err := hydrateUser(account)
	if err != nil {
		return AuthResult{}, err
	}
	var session webauthn.SessionData
	if err := json.Unmarshal(challenge.SessionData, &session); err != nil {
		return AuthResult{}, fmt.Errorf("decode registration ceremony: %w", err)
	}
	credential, err := s.webAuthn.FinishRegistration(user, session, request)
	if err != nil {
		return AuthResult{}, apperror.Wrap(http.StatusBadRequest, "invalid_passkey_response", "The passkey response could not be verified.", err)
	}
	credentialJSON, err := json.Marshal(credential)
	if err != nil {
		return AuthResult{}, err
	}
	codes, hashes, err := newRecoveryKit()
	if err != nil {
		return AuthResult{}, err
	}
	authSessionID := uuid.New()
	refreshID, refreshRaw, refreshHash, err := NewOpaqueToken()
	if err != nil {
		return AuthResult{}, err
	}
	now := s.now().UTC()
	identity, err := s.store.ActivateAccount(
		ctx,
		account.ID,
		credential.ID,
		credentialJSON,
		cleanLabel(label),
		hashes,
		device,
		authSessionID,
		now.Add(s.refreshTTL),
		refreshID,
		refreshHash,
		now.Add(s.refreshTTL),
	)
	if err != nil {
		return AuthResult{}, err
	}
	return s.authResult(ctx, identity, refreshRaw, &domain.RecoveryKit{
		AccountID:      account.ID,
		RecoveryHandle: account.RecoveryHandle,
		Codes:          codes,
	})
}

func (s *Service) BeginLogin(ctx context.Context) (CeremonyOptions, error) {
	options, session, err := s.webAuthn.BeginDiscoverableLogin(
		webauthn.WithUserVerification(protocol.VerificationRequired),
	)
	if err != nil {
		return CeremonyOptions{}, fmt.Errorf("begin passkey login: %w", err)
	}
	sessionJSON, err := json.Marshal(session)
	if err != nil {
		return CeremonyOptions{}, err
	}
	challengeID := uuid.New()
	if err := s.store.CreateChallenge(ctx, challengeID, nil, "login", sessionJSON, s.now().Add(s.challengeTTL)); err != nil {
		return CeremonyOptions{}, err
	}
	return CeremonyOptions{ChallengeID: challengeID, PublicKey: options.Response}, nil
}

func (s *Service) FinishLogin(
	ctx context.Context,
	challengeID uuid.UUID,
	request *http.Request,
	device domain.DeviceInfo,
) (AuthResult, error) {
	challenge, err := s.store.ConsumeChallenge(ctx, challengeID, "login")
	if err != nil {
		return AuthResult{}, apperror.New(http.StatusGone, "ceremony_expired", "Start passkey sign-in again.")
	}
	var session webauthn.SessionData
	if err := json.Unmarshal(challenge.SessionData, &session); err != nil {
		return AuthResult{}, fmt.Errorf("decode login ceremony: %w", err)
	}
	var selected *webAuthnUser
	handler := func(rawID, userHandle []byte) (webauthn.User, error) {
		account, err := s.store.GetWebAuthnAccountByHandle(ctx, userHandle)
		if err != nil {
			return nil, errors.New("unknown passkey")
		}
		user, err := hydrateUser(account)
		if err != nil {
			return nil, err
		}
		found := false
		for _, credential := range user.credentials {
			if bytes.Equal(credential.ID, rawID) {
				found = true
				break
			}
		}
		if !found {
			return nil, errors.New("passkey does not belong to account")
		}
		selected = user
		return user, nil
	}
	_, credential, err := s.webAuthn.FinishPasskeyLogin(handler, session, request)
	if err != nil || selected == nil {
		return AuthResult{}, apperror.Wrap(http.StatusUnauthorized, "invalid_passkey_response", "The passkey response could not be verified.", err)
	}
	credentialJSON, err := json.Marshal(credential)
	if err != nil {
		return AuthResult{}, err
	}
	authSessionID := uuid.New()
	refreshID, refreshRaw, refreshHash, err := NewOpaqueToken()
	if err != nil {
		return AuthResult{}, err
	}
	now := s.now().UTC()
	identity, err := s.store.CreateLoginSession(
		ctx,
		selected.account.ID,
		credential.ID,
		credentialJSON,
		device,
		authSessionID,
		now.Add(s.refreshTTL),
		refreshID,
		refreshHash,
		now.Add(s.refreshTTL),
	)
	if err != nil {
		return AuthResult{}, err
	}
	return s.authResult(ctx, identity, refreshRaw, nil)
}

func (s *Service) BeginAddPasskey(ctx context.Context, accountID uuid.UUID) (CeremonyOptions, error) {
	account, err := s.store.GetWebAuthnAccountByID(ctx, accountID)
	if err != nil {
		return CeremonyOptions{}, err
	}
	user, err := hydrateUser(account)
	if err != nil {
		return CeremonyOptions{}, err
	}
	options, session, err := s.webAuthn.BeginRegistration(
		user,
		webauthn.WithAuthenticatorSelection(protocol.AuthenticatorSelection{
			ResidentKey:      protocol.ResidentKeyRequirementRequired,
			UserVerification: protocol.VerificationRequired,
		}),
	)
	if err != nil {
		return CeremonyOptions{}, err
	}
	sessionJSON, err := json.Marshal(session)
	if err != nil {
		return CeremonyOptions{}, err
	}
	challengeID := uuid.New()
	if err := s.store.CreateChallenge(ctx, challengeID, &accountID, "add_passkey", sessionJSON, s.now().Add(s.challengeTTL)); err != nil {
		return CeremonyOptions{}, err
	}
	return CeremonyOptions{ChallengeID: challengeID, PublicKey: options.Response}, nil
}

func (s *Service) FinishAddPasskey(
	ctx context.Context,
	accountID uuid.UUID,
	challengeID uuid.UUID,
	request *http.Request,
	label string,
) error {
	challenge, err := s.store.ConsumeChallenge(ctx, challengeID, "add_passkey")
	if err != nil || challenge.AccountID == nil || *challenge.AccountID != accountID {
		return apperror.New(http.StatusGone, "ceremony_expired", "Start passkey setup again.")
	}
	account, err := s.store.GetWebAuthnAccountByID(ctx, accountID)
	if err != nil {
		return err
	}
	user, err := hydrateUser(account)
	if err != nil {
		return err
	}
	var session webauthn.SessionData
	if err := json.Unmarshal(challenge.SessionData, &session); err != nil {
		return err
	}
	credential, err := s.webAuthn.FinishRegistration(user, session, request)
	if err != nil {
		return apperror.Wrap(http.StatusBadRequest, "invalid_passkey_response", "The passkey response could not be verified.", err)
	}
	credentialJSON, err := json.Marshal(credential)
	if err != nil {
		return err
	}
	return s.store.AddCredential(ctx, accountID, credential.ID, credentialJSON, cleanLabel(label))
}

func (s *Service) Recover(
	ctx context.Context,
	recoveryHandle string,
	code string,
	device domain.DeviceInfo,
) (AuthResult, error) {
	account, records, err := s.store.RecoveryCodes(ctx, strings.ToUpper(strings.TrimSpace(recoveryHandle)))
	if err != nil {
		return AuthResult{}, apperror.New(http.StatusUnauthorized, "invalid_recovery", "The recovery details are not valid.")
	}
	position := -1
	for _, record := range records {
		if VerifyRecoveryCode(code, record.Hash) {
			position = record.Position
			break
		}
	}
	if position < 0 {
		return AuthResult{}, apperror.New(http.StatusUnauthorized, "invalid_recovery", "The recovery details are not valid.")
	}
	authSessionID := uuid.New()
	refreshID, refreshRaw, refreshHash, err := NewOpaqueToken()
	if err != nil {
		return AuthResult{}, err
	}
	now := s.now().UTC()
	identity, err := s.store.UseRecoveryCode(
		ctx,
		account.ID,
		position,
		device,
		authSessionID,
		now.Add(s.refreshTTL),
		refreshID,
		refreshHash,
		now.Add(s.refreshTTL),
	)
	if err != nil {
		return AuthResult{}, apperror.New(http.StatusUnauthorized, "invalid_recovery", "The recovery code was already used.")
	}
	return s.authResult(ctx, identity, refreshRaw, nil)
}

func (s *Service) Refresh(ctx context.Context, raw string) (AuthResult, error) {
	oldID, oldHash, err := ParseOpaqueToken(raw)
	if err != nil {
		return AuthResult{}, apperror.ErrUnauthorized
	}
	newID, newRaw, newHash, err := NewOpaqueToken()
	if err != nil {
		return AuthResult{}, err
	}
	identity, err := s.store.RotateRefresh(ctx, oldID, oldHash, newID, newHash, s.now().Add(s.refreshTTL))
	if errors.Is(err, store.ErrRefreshReuse) {
		return AuthResult{}, apperror.New(http.StatusUnauthorized, "refresh_reuse_detected", "This session was revoked because a refresh token was reused.")
	}
	if err != nil {
		return AuthResult{}, apperror.ErrUnauthorized
	}
	return s.authResult(ctx, identity, newRaw, nil)
}

func (s *Service) ParseAccessToken(raw string) (domain.AuthIdentity, error) {
	return s.tokens.Parse(raw)
}

func (s *Service) RegenerateRecoveryCodes(ctx context.Context, accountID uuid.UUID) (domain.RecoveryKit, error) {
	account, err := s.store.Account(ctx, accountID)
	if err != nil {
		return domain.RecoveryKit{}, err
	}
	codes, hashes, err := newRecoveryKit()
	if err != nil {
		return domain.RecoveryKit{}, err
	}
	if err := s.store.ReplaceRecoveryCodes(ctx, accountID, hashes); err != nil {
		return domain.RecoveryKit{}, err
	}
	return domain.RecoveryKit{AccountID: accountID, RecoveryHandle: account.RecoveryHandle, Codes: codes}, nil
}

func (s *Service) authResult(
	ctx context.Context,
	identity domain.AuthIdentity,
	refreshRaw string,
	recoveryKit *domain.RecoveryKit,
) (AuthResult, error) {
	access, expiresAt, err := s.tokens.Issue(identity)
	if err != nil {
		return AuthResult{}, err
	}
	account, err := s.store.Account(ctx, identity.AccountID)
	if err != nil {
		return AuthResult{}, err
	}
	account.InstallationID = &identity.InstallationID
	return AuthResult{
		Tokens: domain.TokenPair{
			AccessToken:  access,
			TokenType:    "Bearer",
			ExpiresIn:    int64(s.accessTTL.Seconds()),
			ExpiresAt:    expiresAt,
			RefreshToken: refreshRaw,
		},
		Account:     account,
		RecoveryKit: recoveryKit,
	}, nil
}

func hydrateUser(account store.WebAuthnAccount) (*webAuthnUser, error) {
	user := &webAuthnUser{account: account}
	for _, raw := range account.Credentials {
		var credential webauthn.Credential
		if err := json.Unmarshal(raw, &credential); err != nil {
			return nil, fmt.Errorf("decode passkey credential: %w", err)
		}
		user.credentials = append(user.credentials, credential)
	}
	return user, nil
}

func newRecoveryKit() ([]string, []string, error) {
	codes, err := GenerateRecoveryCodes(recoveryCodeCount)
	if err != nil {
		return nil, nil, err
	}
	hashes := make([]string, len(codes))
	for i, code := range codes {
		hashes[i], err = HashRecoveryCode(code)
		if err != nil {
			return nil, nil, err
		}
	}
	return codes, hashes, nil
}

func cleanLabel(label string) string {
	label = strings.TrimSpace(label)
	if label == "" {
		return "Passkey"
	}
	runes := []rune(label)
	if len(runes) > 80 {
		runes = runes[:80]
	}
	return string(runes)
}

func DecodeCredentialID(value string) ([]byte, error) {
	decoded, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(decoded) == 0 {
		return nil, errors.New("invalid credential id")
	}
	return decoded, nil
}
