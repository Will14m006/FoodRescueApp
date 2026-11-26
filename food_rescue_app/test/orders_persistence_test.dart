// Persistence test: apa yang benar-benar disimpan di perangkat.
//
// Setelah sesi 5, data pesanan tinggal di server. Yang masih lokal hanya:
//   1. sesi (token + profil ringkas)  -> `SessionStore`
//   2. foto bukti pengambilan         -> `ProofPhotoStore`
//
// Test ini menjaga dua hal itu tetap bertahan setelah aplikasi "dibuka ulang".

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/core/session/session_store.dart';
import 'package:food_rescue_app/models/user_role.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/proof_photo_store.dart';

const _user = AuthUser(
  id: 7,
  name: 'William',
  email: 'william@foodrescue.id',
  role: UserRole.merchant,
  token: 'token-abc',
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SessionStore', () {
    test('sesi bertahan setelah store dibuka ulang', () async {
      await SessionStore().write(StoredSession.fromUser(_user));

      // Instance baru = aplikasi dibuka ulang.
      final restored = await SessionStore().read();

      expect(restored, isNotNull);
      expect(restored!.token, 'token-abc');
      expect(restored.id, 7);
      expect(restored.name, 'William');
      expect(restored.email, 'william@foodrescue.id');
      expect(restored.role, UserRole.merchant);
    });

    test('password tidak pernah ikut tersimpan', () async {
      await SessionStore().write(StoredSession.fromUser(_user));

      final raw = await SharedPreferencesAsync().getString('food_rescue_session');

      expect(raw, isNotNull);
      expect(raw!.contains('password'), isFalse);
      expect(raw.contains('token-abc'), isTrue);
    });

    test('logout menghapus sesi', () async {
      final store = SessionStore();
      await store.write(StoredSession.fromUser(_user));
      await store.clear();

      expect(await store.read(), isNull);
    });

    test('data korup dianggap belum login, bukan crash', () async {
      await SharedPreferencesAsync()
          .setString('food_rescue_session', '{bukan json');

      expect(await SessionStore().read(), isNull);
    });

    test('sesi tanpa token ditolak', () async {
      await SharedPreferencesAsync()
          .setString('food_rescue_session', '{"id":1,"name":"X"}');

      expect(await SessionStore().read(), isNull);
    });
  });

  group('ProofPhotoStore', () {
    test('foto bertahan setelah store dibuka ulang', () async {
      await ProofPhotoStore(userId: 7).save(42, 'BASE64FOTO');

      expect(await ProofPhotoStore(userId: 7).read(42), 'BASE64FOTO');
    });

    test('beberapa pesanan disimpan tanpa saling menimpa', () async {
      final store = ProofPhotoStore(userId: 7);
      await store.save(1, 'A');
      await store.save(2, 'B');
      await store.save(1, 'A2');

      expect(await store.loadAll(), {'1': 'A2', '2': 'B'});
    });

    test('foto milik akun lain tidak terbaca', () async {
      await ProofPhotoStore(userId: 7).save(42, 'FOTO');

      expect(await ProofPhotoStore(userId: 8).read(42), isNull);
    });

    test('penghapusan hanya menyentuh akun sendiri', () async {
      await ProofPhotoStore(userId: 7).save(1, 'A');
      await ProofPhotoStore(userId: 8).save(1, 'B');

      await ProofPhotoStore(userId: 7).clear();

      expect(await ProofPhotoStore(userId: 7).loadAll(), isEmpty);
      expect(await ProofPhotoStore(userId: 8).read(1), 'B');
    });
  });
}
