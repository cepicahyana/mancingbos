# IndoFish

Aplikasi mobile event mancing dan sewa lapak. UI Flutter, API Go, data sesuai folder `doc/`.

## Struktur

| Folder | Isi |
|--------|-----|
| `mobile/` | Aplikasi Flutter (Android / iOS) |
| `api/` | REST API Golang + JWT |
| `doc/` | Product brief, schema, API spec, UI guidelines |

## Menjalankan API

Pakai MySQL (Laragon di mesin ini, port `3306`). Pastikan MySQL sudah Start di Laragon, lalu:

```powershell
cd api
copy .env.example .env
go run ./cmd/server
```

API membuat database `indofish` plus tabel jika belum ada.

API: `http://localhost:8080`

Akun seed (password semua: `password`):

- `user@example.com` — pencinta mancing
- `owner@example.com` — pemilik lapak
- `operator@example.com` — operator
- `admin@example.com` — admin
- `superadmin@indofish.test` — superadmin

Jika password root Laragon tidak kosong, isi `DB_PASSWORD` di `api/.env`.

## Menjalankan aplikasi mobile

```powershell
cd mobile
flutter pub get
flutter run
```

Emulator Android memakai `http://10.0.2.2:8080`. HP fisik:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Ganti IP dengan alamat komputer yang menjalankan API.

## Fitur MVP

1. Daftar event mancing
2. Pembuatan event oleh pemilik lapak
3. Penyewaan lapak
4. Input berat ikan oleh operator
5. Pengelolaan data user oleh admin
