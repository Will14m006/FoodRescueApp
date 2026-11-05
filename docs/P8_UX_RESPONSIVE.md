# P8: Layout Adaptif, Keyboard-Safe, Accessibility & Feedback

> "01 Layout adaptif (layar besar / layar kecil) · 02 Keyboard-safe UI ·
> 03 Accessibility dasar · 04 Feedback aksi — jangan membuat user bertanya
> 'ini sedang menunggu atau bagaimana?'"
>
> Reviewer melakukan review sambil program di-RUN.

## Screenshot hasil (4 wajib + 2 tambahan)

| # | File | Membuktikan |
|---|---|---|
| 1 | `docs/screenshots/p8_01_login_mobile.png` | Layout layar kecil (412x892): form full-width, tidak ada yang terpotong |
| 2 | `docs/screenshots/p8_02_keyboard_safe.png` | **Keyboard-safe**: viewport menyusut 892→500, field Password yang difokus tetap terlihat penuh (tidak tertutup keyboard) |
| 3 | `docs/screenshots/p8_03_dashboard_mobile.png` | Layout layar kecil: katalog **1 kolom**, chip kategori bisa di-scroll horizontal |
| 4 | `docs/screenshots/p8_04_dashboard_desktop.png` | Layout layar besar (1440x900): katalog **3 kolom**, konten dibatasi 1100px agar tidak melebar |
| 5 | `docs/screenshots/p8_05_profile_mobile.png` | Profil di layar kecil: menu jadi `ListView` (tidak overflow), target sentuh besar, tooltip "Notifikasi" muncul saat hover |
| 6 | `docs/screenshots/p8_06_feedback_snackbar.png` | **Feedback aksi**: tekan menu "Bantuan" → snackbar "Pusat bantuan segera hadir di versi berikutnya" (tidak diam) |

Screenshot dihasilkan otomatis (bukan mock):

```bash
cd food_rescue_app
flutter build web --no-pub
node tool/p8_screenshots.mjs   # Chrome headless + CDP
```

## 01 — Layout Adaptif

| Komponen | File | Perilaku |
|---|---|---|
| `ResponsiveBody` | `lib/widgets/responsive_body.dart` | Membungkus konten, `maxWidth` 480–1100 px, `Align(topCenter)` |
| `Breakpoints` | `lib/widgets/responsive_body.dart` | `compact` < 600, `medium` 600–900, `expanded` ≥ 900 |
| Grid katalog | `dashboard_screen.dart` | `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400)` → 1 kolom di HP, 3+ kolom di desktop, otomatis tanpa `if` |
| Profil | `profile_screen.dart` | `Column + Spacer` → `ListView` supaya layar pendek tidak overflow |
| Login | `login_screen.dart` | Form dibatasi 480 px, tetap di tengah di layar lebar |

Bukti: screenshot #3 (1 kolom) vs #4 (3 kolom) — build yang sama, hanya lebar viewport berbeda.

## 02 — Keyboard-safe UI

| Layar | Perbaikan |
|---|---|
| Login | `SingleChildScrollView` + `padding.bottom = MediaQuery.viewInsetsOf(context).bottom` |
| Booking | sama, plus `textInputAction: next/done` supaya tombol Enter pindah field, bukan menutup keyboard |
| Form field | `AppTextField` sekarang menerima `textInputAction` & `autofillHints` |

Cara uji di HP/web:
1. Buka login, tap field **Password**.
2. Keyboard naik → field otomatis di-scroll ke area terlihat (screenshot #2).
3. Tekan **Next** di keyboard → pindah ke field berikutnya, bukan menutup form.

## 03 — Accessibility Dasar

| Item | Sebelum | Sesudah |
|---|---|---|
| Tombol ikon header | `GestureDetector` + `Container` (~34 px, tanpa label) | `CircleIconButton` → `IconButton` + `tooltip`, target **48x48** |
| Tombol aksi pesanan | `GestureDetector` (tanpa ripple) | `TextButton.icon` tinggi **44 px**, ada ripple & label |
| Menu profil | `GestureDetector` | `Material` + `InkWell`, `minHeight: 56` |
| Field form | label visual saja | `Semantics(label: ..., textField: true)` → dibacakan screen reader |
| Card makanan | teks terpisah-pisah | `Semantics` satu label ringkas: nama, toko, harga, sisa, jam ambil |
| Tombol "Pesan" | tinggi 34 px | tinggi **44 px** (nyaman disentuh) |
| Kontras teks | `textSecondary #5D6B65` di atas putih | rasio ±5.9:1 (lolos WCAG AA) |

Uji cepat:
- **TalkBack / VoiceOver**: aktifkan, geser fokus → tiap tombol dibacakan ("Status Pesanan", "Profil", bukan "tombol").
- **Flutter web**: hover ikon header → tooltip muncul (terlihat di screenshot #5).

## 04 — Feedback Aksi

Prinsip: **setiap aksi harus menghasilkan respons terlihat** dalam < 100 ms.

| Aksi | Feedback |
|---|---|
| Tap menu yang belum ada layarnya (Alamat/Notifikasi/Bantuan/Tentang) | snackbar "… segera hadir di versi berikutnya" |
| Tandai "Sudah Pickup" | snackbar sukses "Pesanan ditandai sudah diambil." |
| Tap "Batalkan" | **dialog konfirmasi** (sebelumnya langsung eksekusi) → snackbar "Pesanan dibatalkan." |
| Logout | dialog konfirmasi → pindah ke login |
| Submit booking | tombol spinner + teks "Sedang memproses pesanan..." + tombol disabled |
| Login | tombol "Memproses..." + spinner + kotak error merah bila gagal |
| Ambil foto | spinner di dalam dialog, "Konfirmasi" disabled sampai foto ada |
| Semua tombol & menu | ripple Material (InkWell / Material button) |

Helper terpusat: `lib/core/ui/app_feedback.dart` (`AppFeedback.success/error/info`).

## Testing

```bash
cd food_rescue_app
flutter test          # 58 test lulus
flutter analyze       # No issues found
```

Test baru — `test/p8_ux_test.dart` (6 test):

| Test | Yang dibuktikan |
|---|---|
| layout adaptif: 1 kolom vs 2+ kolom | `maxCrossAxisExtent` grid mengikuti lebar layar |
| konten dibatasi lebar di layar besar | lebar `ConstrainedBox` ≤ 1100 px |
| keyboard-safe: field tetap terlihat | `viewInsets.bottom = 300` → rect field masih di dalam layar |
| tombol ikon punya tooltip & 48 px | semua `CircleIconButton` punya tooltip + ukuran ≥ 48x48 |
| field punya label screen reader | `find.bySemanticsLabel('Email / Username')` & `'Password'` ketemu |
| menu tanpa layar memberi pesan | teks "segera hadir" muncul setelah tap |

## Cara Demo ke Reviewer (RUN aplikasi)

```bash
cd food_rescue_app
flutter run -d chrome
```

**A. Layout adaptif**
1. Login (`emilys` / `emilyspass`) → dashboard muncul 1 kolom.
2. Kecilkan/lebarkan jendela Chrome, atau tekan `F12` → Device Toolbar → pilih *iPhone SE* lalu *Desktop 1440px*.
3. Amati: HP = 1 kolom, desktop = 3 kolom, konten tetap di tengah (maks 1100 px).

**B. Keyboard-safe**
4. Logout (Profil → Keluar) → kembali ke login.
5. Tap field **Password** → keyboard/browser mengecilkan viewport; field tetap terlihat.
6. Tap field **Nama Pemesan** di halaman booking → tombol "Pesan Sekarang" bisa di-scroll tanpa tertutup.

**C. Accessibility**
7. Hover ikon header (Status / Riwayat / Profil) → tooltip muncul.
8. (Opsional) Aktifkan TalkBack/VoiceOver → tiap tombol & field dibacakan dengan namanya.
9. Zoom browser 200% → tidak ada teks terpotong.

**D. Feedback aksi**
10. Profil → tap **Bantuan** → snackbar "Pusat bantuan segera hadir…".
11. Status Pesanan → **Batalkan** → muncul dialog konfirmasi, lalu snackbar "Pesanan dibatalkan.".
12. Status Pesanan → **Sudah Pickup** → dialog foto → setelah konfirmasi muncul snackbar sukses.
13. Booking → tap "Pesan Sekarang" → tombol berubah spinner + "Sedang memproses pesanan...".

## Prompt AI yang Digunakan

* "Buat widget `ResponsiveBody` yang membatasi lebar konten dan `Breakpoints` untuk compact/medium/expanded, lalu terapkan ke dashboard, login, booking, profil."
* "Kenapa form tertutup keyboard di Flutter? Perbaiki dengan `MediaQuery.viewInsetsOf(context).bottom` di padding scroll view."
* "Ganti semua `GestureDetector` pada tombol ikon & menu menjadi `IconButton`/`InkWell` dengan tooltip dan target sentuh minimal 48x48 untuk aksesibilitas."
* "Buat helper `AppFeedback` (snackbar sukses/error/info) dan pakai di semua aksi: pickup, batal, menu placeholder."
* "Bagaimana mengambil screenshot aplikasi Flutter web secara otomatis?" — jawaban: Chrome headless + CDP (`tool/p8_screenshots.mjs`).

## Bagian yang Saya Periksa / Perbaiki Sendiri

* Menemukan bahwa `Column + Spacer` di profil **overflow** saat layar pendek → diganti `ListView`.
* Menemukan `double.infinity` di dalam `AlertDialog` menyebabkan error layout (`width.isFinite`) pada P7 → tetap dijaga lebar tetap.
* Menambahkan **dialog konfirmasi** pada tombol "Batalkan" — sebelumnya sekali tap langsung membatalkan pesanan (rawan salah tekan).
* Menyesuaikan tinggi tombol "Pesan" di `FoodCard` dari 34 px ke 44 px setelah mencoba tap di layar HP sempit.
* Memastikan semua menu placeholder memberi pesan; sebelumnya `onTap: () {}` membuat user mengira aplikasi hang.
* Memeriksa screenshot satu per satu: screenshot keyboard-safe awalnya tidak membuktikan apa pun karena field belum difokus — diperbaiki dengan klik field Password dulu.
