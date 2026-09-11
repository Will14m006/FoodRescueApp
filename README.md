# 🍲 Food Rescue App

Food Rescue App adalah aplikasi *mobile* yang dirancang untuk menghubungkan restoran, kafe, atau *bakery* yang memiliki makanan surplus layak konsumsi di akhir jam operasional dengan pelanggan yang ingin membeli makanan tersebut dengan harga diskon. 

Proyek ini dikembangkan sebagai bagian dari tugas *Project-Based Learning* (PBL) mata kuliah Pemrograman Mobile untuk mendigitalisasi proses penyelamatan makanan dan mengurangi limbah organik.

## 🚨 Problem

Banyak restoran dan toko roti terpaksa membuang makanan layak konsumsi (*food waste*) di akhir jam operasional karena tidak habis terjual. Di sisi lain, banyak mahasiswa atau pekerja yang mencari opsi makanan berkualitas dengan anggaran terbatas, terutama di malam hari. Belum ada platform lokal yang efisien untuk mempertemukan ketersediaan makanan surplus ini dengan pembeli secara *real-time*.

## 🌟 Fitur Utama

* **Multi-Role Authentication:** Sistem *login* yang memisahkan hak akses dan antarmuka untuk akun Mitra (Penjual) dan akun Pembeli.
* **Merchant Dashboard (Manajemen Kuota):** Mitra dapat mengunggah "Paket Penyelamat", menentukan kuota harian, mengatur harga diskon, dan menetapkan batas waktu pengambilan (*pick-up window*).
* **Katalog Surplus (Buyer Feed):** Halaman utama yang menampilkan daftar makanan sisa yang tersedia hari ini dari berbagai mitra secara aktual.
* **Sistem Booking & Pick-up Code:** Pembeli dapat memesan makanan dan mendapatkan kode unik (misal: RESCUE-123) untuk ditukarkan di lokasi.
* **Validasi Pesanan:** Fitur bagi mitra untuk memvalidasi kode unik saat pelanggan mengambil makanan, yang secara otomatis mencatat transaksi selesai di *database*.

## 🛠️ Tech Stack & Arsitektur Sistem

* **Mobile Frontend:** Flutter (Dart) / Kotlin 
* **Backend & Web Admin:** Laravel (PHP) terintegrasi dengan RESTful API
* **Database Pusat:** MySQL 
* **Penyimpanan Lokal (Mobile):** SQLite / Shared Preferences 
* **Environment:** Android Studio & Android SDK