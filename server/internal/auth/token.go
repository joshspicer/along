package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/joshspicer/along/server/internal/domain"
)

const (
	issuer   = "along-server"
	audience = "along-mobile"
)

type Claims struct {
	SessionID      string `json:"sid"`
	InstallationID string `json:"did"`
	jwt.RegisteredClaims
}

type TokenManager struct {
	key []byte
	ttl time.Duration
	now func() time.Time
}

func NewTokenManager(key []byte, ttl time.Duration) *TokenManager {
	return &TokenManager{key: key, ttl: ttl, now: time.Now}
}

func (m *TokenManager) Issue(identity domain.AuthIdentity) (string, time.Time, error) {
	now := m.now().UTC()
	expires := now.Add(m.ttl)
	claims := Claims{
		SessionID:      identity.SessionID.String(),
		InstallationID: identity.InstallationID.String(),
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    issuer,
			Subject:   identity.AccountID.String(),
			Audience:  jwt.ClaimStrings{audience},
			ExpiresAt: jwt.NewNumericDate(expires),
			NotBefore: jwt.NewNumericDate(now.Add(-5 * time.Second)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(m.key)
	return signed, expires, err
}

func (m *TokenManager) Parse(raw string) (domain.AuthIdentity, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(
		raw,
		claims,
		func(token *jwt.Token) (any, error) {
			if token.Method != jwt.SigningMethodHS256 {
				return nil, fmt.Errorf("unexpected signing method %s", token.Method.Alg())
			}
			return m.key, nil
		},
		jwt.WithAudience(audience),
		jwt.WithIssuer(issuer),
		jwt.WithExpirationRequired(),
		jwt.WithLeeway(5*time.Second),
	)
	if err != nil || !token.Valid {
		return domain.AuthIdentity{}, errors.New("invalid access token")
	}
	accountID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return domain.AuthIdentity{}, errors.New("invalid account subject")
	}
	sessionID, err := uuid.Parse(claims.SessionID)
	if err != nil {
		return domain.AuthIdentity{}, errors.New("invalid session claim")
	}
	installationID, err := uuid.Parse(claims.InstallationID)
	if err != nil {
		return domain.AuthIdentity{}, errors.New("invalid installation claim")
	}
	return domain.AuthIdentity{
		AccountID:      accountID,
		SessionID:      sessionID,
		InstallationID: installationID,
	}, nil
}

func NewOpaqueToken() (id uuid.UUID, raw string, hash []byte, err error) {
	id = uuid.New()
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		return uuid.Nil, "", nil, err
	}
	encoded := base64.RawURLEncoding.EncodeToString(secret)
	raw = id.String() + "." + encoded
	sum := sha256.Sum256([]byte(raw))
	return id, raw, sum[:], nil
}

func ParseOpaqueToken(raw string) (uuid.UUID, []byte, error) {
	parts := strings.Split(raw, ".")
	if len(parts) != 2 {
		return uuid.Nil, nil, errors.New("malformed refresh token")
	}
	id, err := uuid.Parse(parts[0])
	if err != nil {
		return uuid.Nil, nil, errors.New("malformed refresh token")
	}
	if decoded, err := base64.RawURLEncoding.DecodeString(parts[1]); err != nil || len(decoded) != 32 {
		return uuid.Nil, nil, errors.New("malformed refresh token")
	}
	sum := sha256.Sum256([]byte(raw))
	return id, sum[:], nil
}
