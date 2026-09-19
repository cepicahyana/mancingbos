# Database Schema: IndoFish

**Dibuat:** Sabtu, 19 September 2026
**Database:** MySQL

---

### Tabel: `users`

| Kolom | Tipe/Keterangan |
|-------|----------------|
| id, name, email, role, created_at, updated_at | - |

**Catatan:** Menampung data semua pengguna aplikasi.

### Tabel: `events`

| Kolom | Tipe/Keterangan |
|-------|----------------|
| id, owner_id, title, description, date, location, created_at, updated_at | - |

**Catatan:** Data event mancing yang dibuat oleh pemilik lapak.

### Tabel: `weights`

| Kolom | Tipe/Keterangan |
|-------|----------------|
| id, event_id, user_id, weight, created_at | - |

**Catatan:** Data berat ikan yang diinput oleh operator.

---

## Relasi

Pastikan relasi antara tabel users, events, dan weights terdefinisi dengan baik.

---

## Konvensi

- Primary key: `id` (BIGINT UNSIGNED AUTO_INCREMENT)
- Timestamp: `created_at`, `updated_at`
- Soft delete: `deleted_at` (jika diperlukan)
- Foreign key: `{table_singular}_id`
