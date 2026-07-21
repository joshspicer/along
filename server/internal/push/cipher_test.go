package push

import "testing"

func TestCipherRoundTripAndTamper(t *testing.T) {
	t.Parallel()
	cipher, err := NewCipher([]byte("0123456789abcdef0123456789abcdef"))
	if err != nil {
		t.Fatal(err)
	}
	plaintext := []byte("private-device-token")
	encrypted, err := cipher.Encrypt(plaintext)
	if err != nil {
		t.Fatal(err)
	}
	if string(encrypted) == string(plaintext) {
		t.Fatal("ciphertext matches plaintext")
	}
	decrypted, err := cipher.Decrypt(encrypted)
	if err != nil {
		t.Fatal(err)
	}
	if string(decrypted) != string(plaintext) {
		t.Fatalf("decrypted = %q", decrypted)
	}
	encrypted[len(encrypted)-1] ^= 0xff
	if _, err := cipher.Decrypt(encrypted); err == nil {
		t.Fatal("tampered ciphertext was accepted")
	}
}

func TestCipherRejectsWrongKeySize(t *testing.T) {
	t.Parallel()
	if _, err := NewCipher([]byte("short")); err == nil {
		t.Fatal("accepted invalid key size")
	}
}
