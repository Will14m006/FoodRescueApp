// Smoke test manual ke API sungguhan (bukan unit test).
// Jalankan: dart run tool/api_smoke.dart
// ignore_for_file: avoid_print
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

Future<void> main() async {
  final catalog = await ApiSurplusFoodRepository().fetchSurplusFoods();
  print('GET katalog  -> ${catalog.length} item');
  for (final f in catalog.take(3)) {
    print('  ${f.emoji} ${f.name} | ${f.formattedDiscountPrice} | sisa ${f.quota}');
  }

  final order = await ApiOrderRepository().createOrder(
    buyerName: 'William',
    surplusFoodId: catalog.first.id,
    surplusFoodName: catalog.first.name,
    quantity: 2,
    unitPrice: catalog.first.discountPrice,
  );
  print('POST pesanan -> ${order.id} / ${order.pickupCode} / Rp ${order.totalPrice}');
}
