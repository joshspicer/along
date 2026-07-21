package auth

import "testing"

func TestRecoveryCodesAreUniqueAndVerifiable(t *testing.T) {
	t.Parallel()
	codes, err := GenerateRecoveryCodes(20)
	if err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, code := range codes {
		if seen[code] {
			t.Fatalf("duplicate recovery code %q", code)
		}
		seen[code] = true
		hash, err := HashRecoveryCode(code)
		if err != nil {
			t.Fatal(err)
		}
		if !VerifyRecoveryCode(code, hash) {
			t.Fatalf("code %q did not verify", code)
		}
		if !VerifyRecoveryCode(" "+code+" ", hash) {
			t.Fatalf("normalized code %q did not verify", code)
		}
		if VerifyRecoveryCode(code+"X", hash) {
			t.Fatal("wrong code verified")
		}
	}
}

func TestRecoveryHandle(t *testing.T) {
	t.Parallel()
	first, err := RecoveryHandle()
	if err != nil {
		t.Fatal(err)
	}
	second, err := RecoveryHandle()
	if err != nil {
		t.Fatal(err)
	}
	if first == second || len(first) < 10 {
		t.Fatalf("unexpected handles %q and %q", first, second)
	}
}
