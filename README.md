# 🍲 Food Rescue App

Food Rescue App adalah aplikasi *mobile* yang dirancang untuk menghubungkan restoran, kafe, atau *bakery* yang memiliki makanan surplus layak konsumsi di akhir jam operasional dengan pelanggan yang ingin membeli makanan tersebut dengan harga diskon.

Proyek ini dikembangkan sebagai bagian dari tugas *Project-Based Learning* (PBL) mata kuliah Pemrograman Mobile untuk mendigitalisasi proses penyelamatan makanan dan mengurangi limbah organik.

## 🚨 Problem

Banyak restoran dan toko roti terpaksa membuang makanan layak konsumsi (*food waste*) di akhir jam operasional karena tidak habis terjual. Di sisi lain, banyak mahasiswa atau pekerja yang mencari opsi makanan berkualitas dengan anggaran terbatas, terutama di malam hari. Belum ada platform lokal yang efisien untuk mempertemukan ketersediaan makanan surplus ini dengan pembeli secara *real-time*.

## 🌟 Fitur Utama

* **Autentikasi (API):** Login ke `dummyjson.com/auth/login`, data user tampil di profil, logout dengan konfirmasi.
* **Lokasi (GPS):** Titik jemput terdekat di dashboard, dengan penanganan izin ditolak / GPS mati / diblokir permanen.
* **Kamera:** Foto bukti pengambilan saat menandai pesanan "Sudah Pickup".
* **Merchant Dashboard (Manajemen Kuota):** Mitra dapat mengunggah "Paket Penyelamat", menentukan kuota harian, mengatur harga diskon, dan menetapkan batas waktu pengambilan (*pick-up window*).
* **Katalog Surplus (Buyer Feed):** Halaman utama yang menampilkan daftar makanan sisa yang tersedia hari ini dari berbagai mitra secara aktual.
* **Sistem Booking & Pick-up Code:** Pembeli dapat memesan makanan dan mendapatkan kode unik (misal: RESCUE-101) untuk ditukarkan di lokasi.
* **Validasi Pesanan:** Fitur bagi mitra untuk memvalidasi kode unik saat pelanggan mengambil makanan, yang secara otomatis mencatat transaksi selesai di *database*.

## 🛠️ Tech Stack

* **Mobile Frontend:** Flutter (Dart)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Backend:** Dart (`shelf` + `shelf_router`) — REST API, JWT, bcrypt
* **Database Pusat:** SQLite lewat `drift` (file lokal server, migrasi berversi)
* **Foto Menu:** disimpan sebagai file di `backend/data/uploads/`, nama acak
  dibuat server; hanya JPEG/PNG/WebP yang diterima (diperiksa lewat magic bytes)
* **Penyimpanan Lokal (Mobile):** SharedPreferences
* **Advanced Features:** Autentikasi (HTTP), Lokasi (`geolocator`), Kamera &
  Galeri (`image_picker`)
* **Environment:** Android Studio & Android SDK, VS Code, Flutter SDK

Detail arsitektur dan struktur folder ada di [Architecture.md](./Architecture.md).
Dokumentasi P7 ada di [docs/P7_MVP_ADVANCED.md](./docs/P7_MVP_ADVANCED.md).
Dokumentasi P8 (layout adaptif, keyboard-safe, aksesibilitas, feedback) ada di
[docs/P8_UX_RESPONSIVE.md](./docs/P8_UX_RESPONSIVE.md) beserta screenshot di
[docs/screenshots](./docs/screenshots).
Dokumentasi P9 (test & refactor — hapus duplikasi code, pemisahan tanggung
jawab `ProfileForm` / `Validators` / `ProfileRepository`) ada di
[docs/P9_REFACTOR.md](./docs/P9_REFACTOR.md).
Dokumentasi P10 (runtime logging, perbaikan 5 issue hasil peer review, dan 12
issue untuk aplikasi rekan) ada di [docs/P10_BUGFIX.md](./docs/P10_BUGFIX.md)
serta [docs/P10_ISSUES_SPACE_SYNC.md](./docs/P10_ISSUES_SPACE_SYNC.md).

## 📦 Instalasi & Menjalankan

Backend (wajib jalan lebih dulu):

```bash
cd backend
cp .env.example .env      # isi JWT_SECRET (min. 32 karakter) & BCRYPT_COST
dart pub get
dart run bin/server.dart
```

Aplikasi:

```bash
cd food_rescue_app
flutter pub get
flutter run
```

Untuk build web, origin CORS harus cocok persis:

```bash
cd food_rescue_app
flutter run -d chrome --web-port 5000 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
# backend: CORS_ORIGINS=http://localhost:5000
```

Menjalankan seluruh test:

```bash
cd backend && dart test
cd food_rescue_app && flutter test
```

## 📋 Progress Tracker

| Phase | Deliverable | Status |
|-------|-------------|--------|
| P1 | README.md | ✅ Selesai |
| P2 | Architecture.md | ✅ Selesai |
| P3 | Struktur folder, routing, prototype UI | ✅ Selesai |
| P4 | 2 fitur dengan state management (Riverpod) | ✅ Selesai |
| P5 | Local Data & Persistence (SharedPreferences) | ✅ Selesai |
| P6 | Integrasi API & Vertical Slice (http + 15 unit test) | ✅ Selesai |
| P7 | MVP lengkap + 3 advanced feature (Autentikasi, Lokasi, Kamera) | ✅ Selesai |
| P8 | Layout adaptif, keyboard-safe, accessibility, feedback aksi | ✅ Selesai |
| P9 | Test & refactor: hapus duplikasi code + pisah `ProfileForm`/`Validators`/`ProfileRepository` (70 test) | ✅ Selesai |
| P10 | Runtime logging + perbaikan 5 issue hasil review + 12 issue untuk aplikasi rekan (84 test) | ✅ Selesai |
