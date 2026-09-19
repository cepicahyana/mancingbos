# API Specification: IndoFish

**Dibuat:** Sabtu, 19 September 2026
**Backend:** Laravel

---

## Format Response Standar

### Sukses
```json
REST
```

### Error Validasi (422)
```json
{
  "success": false,
  "message": "Validasi gagal",
  "errors": {
    "field_name": ["Pesan error"]
  }
}
```

### Error Umum (4xx / 5xx)
```json
{
  "success": false,
  "message": "Pesan error"
}
```

---

## Konvensi Endpoint

| Method | Pattern | Keterangan |
|--------|---------|------------|
| GET | /api/{resource} | List dengan pagination |
| GET | /api/{resource}/{id} | Detail |
| POST | /api/{resource} | Create |
| PUT/PATCH | /api/{resource}/{id} | Update |
| DELETE | /api/{resource}/{id} | Delete |

---

## Endpoint (Draft)

> Isi endpoint spesifik seiring development. Contoh:

| Method | Endpoint | Deskripsi | Auth |
|--------|----------|-----------|------|
| POST | /api/auth/login | Login user | Public |
| POST | /api/auth/register | Register user | Public |
| GET | /api/auth/me | Profil user login | Required |

---

## Aturan

- Semua endpoint (kecuali auth) butuh autentikasi
- Gunakan pagination: `?page=1&per_page=15`
- Sorting: `?sort=created_at&order=desc`
- Filter: `?search=keyword&status=active`
