# Prompt Starter — IndoFish

Copy-paste prompt ini ke Cursor untuk memulai development.

---

## Prompt Awal (Setup Project)

```
Kamu developer untuk project "IndoFish".

Baca dulu dokumentasi berikut:
- docs/01-product-brief.md
- docs/03-database-schema.md
- docs/05-ui-guidelines.md
- .cursor/rules/project.mdc

Stack:
- Frontend: Laravel
- Backend: Laravel
- Database: MySQL
- Auth: JWT
- Styling: Tailwind CSS

Stack UI / Library (WAJIB):
- Bootstrap

Task: Setup project dari awal + implementasi Fase 1 dari docs/06-task-backlog.md

Constraint:
- Ikuti semua aturan di .cursor/rules/project.mdc
- Patuhi Stack UI / Library — jangan ganti library/pola UI
- Bahasa UI: Bahasa Indonesia
- Jangan commit
- Jangan tambah fitur di luar MVP

Selesai jika semua item di docs/07-acceptance-criteria.md untuk fase ini terpenuhi.
```

---

## Prompt Lanjutan (Per Fitur)

```
Lanjutkan project "IndoFish".

Baca docs/06-task-backlog.md — kerjakan task berikutnya yang belum selesai.

Sebelum coding:
1. Cek kode yang sudah ada
2. Baca docs/02-user-flows.md untuk fitur ini
3. Ikuti docs/04-api-spec.md untuk API

Jangan ubah modul yang sudah selesai.
Jangan commit.
```

---

## Prompt Fix Bug

```
Ada bug di project "IndoFish":

[JELASKAN BUG DI SINI]

Langkah:
1. Identifikasi root cause
2. Fix dengan minimal perubahan
3. Pastikan tidak break fitur lain
4. Jelaskan apa yang diperbaiki

Ikuti .cursor/rules/project.mdc
```

---

## Prompt Review

```
Review kode project "IndoFish" untuk task [NAMA TASK].

Cek terhadap:
- docs/07-acceptance-criteria.md
- docs/05-ui-guidelines.md
- .cursor/rules/project.mdc

Laporkan: apa yang sudah OK, apa yang kurang, apa yang perlu diperbaiki.
```
