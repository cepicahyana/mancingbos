package auth

import "testing"

func TestPasswordAndTokenRoundTrip(t *testing.T) {
	hash, err := HashPassword("password")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(hash, "password") {
		t.Fatal("password valid ditolak")
	}
	if CheckPassword(hash, "salah") {
		t.Fatal("password salah diterima")
	}

	tok, err := Sign("secret-test", 60, 7, "user@example.com", "owner")
	if err != nil {
		t.Fatal(err)
	}
	c, err := Parse("secret-test", tok)
	if err != nil {
		t.Fatal(err)
	}
	if c.UserID != 7 || c.Email != "user@example.com" || c.Role != "owner" {
		t.Fatalf("claims salah: %+v", c)
	}
	if _, err := Parse("secret-lain", tok); err == nil {
		t.Fatal("token dengan secret salah harus gagal")
	}
}

func TestRoles(t *testing.T) {
	if !PublicRegisterRole("owner") || PublicRegisterRole("admin") {
		t.Fatal("aturan role register salah")
	}
	if !IsAdmin("superadmin") || IsAdmin("owner") {
		t.Fatal("aturan admin salah")
	}
}
