# P9: Test & Refactor (Avoid Duplikasi Code)

> "pastikan tidak ada duplikasi code · pastikan melakukan pemisahan tanggung
> jawab, menjadi function2 yang lebih kecil fokus kepada perkerjaannya:
> ProfileForm: input dan status UI / validation: aturan input /
> profileRepository: request API"
>
> Alur wajib: **1 tes awal lulus → 2 pindahkan satu bagian → 3 tes ulang →
> 4 commit sekarang**.

## Ringkasan hasil

| Ukuran | Sebelum P9 | Sesudah P9 |
|---|---|---|
| Format Rupiah | 3 implementasi berbeda (`Rp 15000`, `Rp 15.000`, `Rp 180rb`) | 1: `Formatters.rupiah` |
| Blok HTTP (post + timeout + decode + error) | disalin di 2 repository | 1: `ApiClient.sendJson` |
| Card pesanan | 2 widget hampir identik (±60 baris) | 1: `OrderCard` + `StatusBadge` |
| Aturan "wajib diisi" / min length / jumlah | ditulis ulang di 2 layar | 1: `Validators` |
| Perubahan baris (refactor) | — | **+298 / −565** |
| Test | 58 lulus | **70 lulus**, `flutter analyze` bersih |

## 1 — Tes awal lulus (baseline)

```
flutter test     -> 00:14 +58: All tests passed!
flutter analyze  -> No issues found!
```

Baseline dicatat **sebelum** satu baris pun diubah, supaya kalau ada yang
pecah jelas berasal dari refactor.

## 2 — Pemisahan tanggung jawab

Tiga contoh konkret sesuai permintaan soal:

### `ProfileForm` — input & status UI

`lib/screens/profile_form_screen.dart`

- hanya membaca/menulis `TextEditingController`, memvalidasi form, dan
  menampilkan status (`isLoading`, tombol "Menyimpan...", snackbar).
- **tidak** tahu endpoint API, **tidak** tahu aturan validasi.
- masuk lewat menu **Profil → Edit Profil** (`AppRoutes.profileEdit`).

### `Validators` — aturan input

`lib/core/validation/validators.dart`

```dart
Validators.required(value, 'Email')            // "Email wajib diisi."
Validators.minLength(value, label: 'Password', min: 6)
Validators.email(value)                        // "Format email tidak valid."
Validators.quantity(value, min: 1, max: quota) // "Melebihi batas maksimal (4)."
```

Dipakai oleh `ProfileFormScreen`, `login_screen`, dan `booking_screen` —
dulu masing-masing menulis ulang logikanya dengan pesan yang berbeda.
Aturan ini bisa diuji **tanpa** membangun widget.

### `ProfileRepository` — request API

`lib/repositories/profile_repository.dart`

```dart
abstract class ProfileRepository {
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String firstName,
    required String lastName,
    required String email,
  });
}
```

`ApiProfileRepository` melakukan `PUT https://dummyjson.com/users/{id}` lewat
`ApiClient` dan mengembalikan `AuthUser` baru (token & id sesi berjalan tetap).
`ProfileUpdateNotifier` (`lib/providers/profile_provider.dart`) memegang
state `AsyncValue`, jadi widget cukup `ref.watch`.

### Duplikasi lain yang dihapus

| Duplikat | Lokasi lama | Pengganti |
|---|---|---|
| Format Rupiah | `surplus_food_model._rupiah`, `booking_screen` (`replaceAllMapped`), `booking_screen` (`'Rp ${total}'`) | `core/utils/formatters.dart` |
| HTTP + timeout + `jsonDecode` + pesan error | `auth_repository`, `order_repository` | `core/network/api_client.dart` |
| Card pesanan + badge status | `order_status_screen._StatusOrderCard`, `orders_screen` | `widgets/order_card.dart` |
| Penyusunan nama lengkap | `auth_repository.fromJson`, `profile` | `AuthUser.fullName(Map)` |
| Layar panjang tanpa fokus | `order_status_screen` (363 baris) | `_StatusHeader`, `_OrderActions`, `_ActionButton`, `_confirmPickup`, `_cancelOrder` |

Catatan: Rupiah yang dulu tidak konsisten (`Rp 15000` tanpa titik pada satu
tombol Total) sekarang otomatis ikut format yang benar karena hanya ada satu
implementasi.

## 3 — Tes ulang

`test/p9_refactor_test.dart` (12 test baru):

| Group | Isi |
|---|---|
| `Validators` | required / minLength / email / quantity — termasuk batas bawah & atas |
| `Formatters` | `rupiah(0)`, `rupiah(1234567)`, `dateTime` 2 digit jam |
| `ApiProfileRepository` | sukses (`PUT` + body terkirim + token lama dipertahankan), HTTP 500, koneksi gagal |
| `ApiClient` | body bukan JSON → error lewat `onError` |
| `ProfileFormScreen` | prefill dari sesi, validasi menahan submit, simpan sukses mengganti state user |

```
flutter test     -> 00:13 +70: All tests passed!
flutter analyze  -> No issues found! (ran in 3.5s)
```

Dua test lama ikut disesuaikan karena pesan validasi sekarang berasal dari
`Validators` (mis. `'Melebihi kuota yang tersedia (maks. 4).'` →
`'Melebihi batas maksimal (4).'`). Perubahan itu **sengaja**: tujuannya satu
sumber pesan, bukan mempertahankan teks yang berbeda-beda.

## 4 — Commit

```bash
git commit -m "refactor(P9): hapus duplikasi code + pisah ProfileForm, Validators, ProfileRepository"
```

Perubahan yang dibuktikan build/test: `+298 / −565` baris, 70 test lulus.
