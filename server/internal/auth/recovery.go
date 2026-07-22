package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/crypto/argon2"
)

const recoveryAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func GenerateRecoveryCodes(count int) ([]string, error) {
	codes := make([]string, count)
	for i := range codes {
		raw := make([]byte, 12)
		random := make([]byte, len(raw))
		if _, err := rand.Read(random); err != nil {
			return nil, err
		}
		for j := range raw {
			raw[j] = recoveryAlphabet[int(random[j])%len(recoveryAlphabet)]
		}
		codes[i] = string(raw[:4]) + "-" + string(raw[4:8]) + "-" + string(raw[8:])
	}
	return codes, nil
}

func HashRecoveryCode(code string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	const memory = 64 * 1024
	const iterations = 3
	const parallelism = 1
	hash := argon2.IDKey([]byte(normalizeCode(code)), salt, iterations, memory, parallelism, 32)
	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memory,
		iterations,
		parallelism,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash),
	), nil
}

func VerifyRecoveryCode(code, encoded string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" || parts[2] != "v=19" {
		return false
	}
	var memory uint32
	var iterations uint32
	var parallelism uint8
	for _, value := range strings.Split(parts[3], ",") {
		pair := strings.SplitN(value, "=", 2)
		if len(pair) != 2 {
			return false
		}
		parsed, err := strconv.ParseUint(pair[1], 10, 32)
		if err != nil {
			return false
		}
		switch pair[0] {
		case "m":
			memory = uint32(parsed)
		case "t":
			iterations = uint32(parsed)
		case "p":
			parallelism = uint8(parsed)
		}
	}
	if memory == 0 || iterations == 0 || parallelism == 0 {
		return false
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false
	}
	expected, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return false
	}
	actual := argon2.IDKey([]byte(normalizeCode(code)), salt, iterations, memory, parallelism, uint32(len(expected)))
	return subtle.ConstantTimeCompare(actual, expected) == 1
}

func RecoveryHandle() (string, error) {
	value := make([]byte, 10)
	if _, err := rand.Read(value); err != nil {
		return "", err
	}
	return strings.ToUpper(base64.RawURLEncoding.EncodeToString(value)), nil
}

func normalizeCode(code string) string {
	var builder strings.Builder
	for _, r := range strings.ToUpper(strings.TrimSpace(code)) {
		if r != '-' && r != ' ' {
			builder.WriteRune(r)
		}
	}
	return builder.String()
}

var ErrRecoveryCodeUsed = errors.New("recovery code is invalid or already used")
