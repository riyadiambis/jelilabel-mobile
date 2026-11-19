# AGENTS.md: Aturan Agen AI NutriScan Mobile

Berlaku untuk semua agen: Gemini di Antigravity (Agy), Claude, dan agen lain.
Baca berkas ini sebelum bekerja. Kalau ada yang bertentangan, urutan acuannya:
`docs/` > berkas ini > permintaan di chat. Bertentangan dengan docs: BERHENTI dan tanya PM.

## Peran

| Peran | Siapa | Tugas |
|---|---|---|
| PM | Riyadi | Memutuskan (pilih A/B/C), uji manual di HP, merge PR |
| Perencana | Claude | Cek docs, tulis PROMPT EKSEKUSI, baca LAPORAN, beri vonis |
| Eksekutor | Agy (default Gemini Flash, effort maksimal) | Tulis ISSUE, ngoding, tes, push branch, tulis LAPORAN |
| Auditor | Claude Sonnet (rutin), Opus (audit akhir sebelum rilis) | Cocokkan LAPORAN dengan diff, bukan percaya klaim |

## Acuan wajib dibaca

- `docs/PRD.md`: fitur F-01 s.d. F-12 dan keputusan K-1 dst.
- `docs/AI-CONTRACT.md`: format JSON Gemini untuk OCR.
- `docs/ATURAN-GIT.md`: branch, commit, worktree, PR.
- `docs/issues/ISSUE-NN-*.md`: tugas yang sedang dikerjakan.

## Alur satu pekerjaan

0. Docs dulu: tulis `docs/issues/ISSUE-NN-nama.md` (tujuan, batasan, tugas,
   kriteria selesai). `git -C docs commit -m "docs(issue-NN): ..."`, push.
1. Branch `feat/issue-NN-nama` atau `fix/issue-NN-nama` dari main terbaru.
2. Kerjakan hanya yang ada di ISSUE. Hal lain yang ditemukan: tulis di LAPORAN, jangan dikerjakan.
3. Tes: `flutter test` dan `flutter analyze` wajib bersih.
4. Commit `feat(issue-NN): ...`, push branch. Jangan merge, jangan buka PR kecuali diminta.
5. Tulis `docs/laporan/LAPORAN-NN.md` (format di bawah), commit ke repo docs.

## Format LAPORAN

```
LAPORAN ISSUE-NN <judul>
- [LULUS/GAGAL] 1. <deskripsi singkat>, lib/...dart:baris
- [LULUS/GAGAL] 2. ...
Tes: <jumlah> lulus, <jumlah> gagal
flutter analyze: <jumlah> masalah
git log --oneline -3 (kode): ...
git log --oneline -3 (docs): ...
Push: <output singkat>
Catatan di luar ISSUE: ...
```
Tanpa bukti `berkas:baris`, item dianggap GAGAL.

## Aturan kode Flutter

- Arsitektur: Clean Architecture per fitur di `lib/features/<fitur>/{data,domain,presentation}`.
- State: Cubit (flutter_bloc) + equatable. DI: get_it. Navigasi: go_router.
- Data lokal: sqflite. Perubahan skema hanya lewat ISSUE yang menyebutnya.
- Warna dan gaya hanya dari tema pusat (`lib/core/theme`), tidak ada kode warna di widget.
  Hijau, kuning, merah status hanya untuk status gizi (K-1).
- Teks UI bahasa Indonesia. Status gizi selalu ada label teks, bukan warna saja.
- Tombol yang memanggil pemindai atau jaringan dikunci selama proses berjalan
  (pelajaran Insap: crash "Reply already submitted").
- Ikuti pola yang sudah ada di repo sebelum membuat pola baru.

## Larangan keras

- Push ke main, `git push --force`, `--force-with-lease`, merge sendiri.
- Menambah paket di `pubspec.yaml` yang tidak disebut ISSUE.
- Menaruh kunci API, `.env`, keystore, atau `google-services.json` rilis di repo.
  Gemini hanya lewat Firebase AI Logic + App Check.
- Menyimpan foto label ke server mana pun.
- Teks yang memberi diagnosis atau saran medis. Acuan batas: Kemenkes (gula 50 g, natrium 2000 mg per hari).
- Menampilkan isi rahasia di LAPORAN: cukup nama berkas dan status.

## Tugas BACA-SAJA (audit, cek)

Kalau prompt menulis BACA-SAJA: dilarang `git commit`, `push`, `checkout -b`,
`flutter pub add`, dan mengubah berkas. Boleh: `git log`, `git diff`, `git status`,
`flutter analyze`, `flutter test`, membaca berkas.
