import 'package:beeyo_customer/blocs/cart_bloc/cart_bloc.dart';
import 'package:beeyo_customer/blocs/stock_cubit/stock_cubit.dart';
import 'package:beeyo_customer/data/repositories/order_repository.dart';
import 'package:beeyo_customer/shared/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

ProductModel _product(String id) => ProductModel(
      id: id,
      title: 'P$id',
      description: '',
      price: '10',
      imageUrl: '',
      unit: 'PIECE',
      categoryId: 'c',
    );

void main() {
  group('StockState', () {
    const state = StockState(
      warehouseId: 'w',
      loaded: true,
      stock: {'out': 0, 'low': 3, 'edge': kLowStockThreshold, 'plenty': 50},
    );

    test('unknown until loaded, so nothing is blocked before the first sync',
        () {
      const notLoaded = StockState(warehouseId: 'w', stock: {'out': 0});
      expect(notLoaded.stockOf('out'), isNull);
      expect(notLoaded.isSoldOut('out'), isFalse);
    });

    test('sold out only at exactly 0; untracked ids stay unknown', () {
      expect(state.isSoldOut('out'), isTrue);
      expect(state.isSoldOut('low'), isFalse);
      expect(state.stockOf('missing'), isNull);
    });

    test('low-stock badge for 1..threshold only', () {
      expect(state.lowStockCount('low'), 3);
      expect(state.lowStockCount('edge'), kLowStockThreshold);
      expect(state.lowStockCount('plenty'), isNull);
      expect(state.lowStockCount('out'), isNull);
    });
  });

  group('CartBloc ApplyStockLimits', () {
    test('removes sold-out lines, clamps over-stock lines, leaves the rest',
        () async {
      final bloc = CartBloc();
      bloc
        ..add(AddToCart(_product('a')))
        ..add(AddToCart(_product('b')))
        ..add(AddToCart(_product('b')))
        ..add(AddToCart(_product('b')))
        ..add(AddToCart(_product('c')))
        ..add(const ApplyStockLimits({'a': 0, 'b': 2, 'c': 9}));
      // The state after the limits apply: 'a' gone, 'c' added before it.
      final state = await bloc.stream
          .firstWhere((s) =>
              s is CartLoaded &&
              s.items.any((i) => i.product.id == 'c') &&
              s.items.every((i) => i.product.id != 'a'))
          .timeout(const Duration(seconds: 2)) as CartLoaded;
      final byId = {for (final i in state.items) i.product.id: i.quantity};
      expect(byId, {'b': 2, 'c': 1});
      expect(state.totalAmount, 30);
      await bloc.close();
    });
  });

  group('InsufficientStockException.tryParse', () {
    test('reads every short item from a 409 body', () {
      const body = '{"success":false,"code":409,"message":"Some items...",'
          '"data":{"code":"INSUFFICIENT_STOCK","items":['
          '{"productId":"p1","name":"Milk","requested":3,"available":1},'
          '{"productId":"p2","name":"Eggs","requested":1,"available":0}]}}';
      final e = InsufficientStockException.tryParse(body)!;
      expect(e.available, {'p1': 1, 'p2': 0});
      expect(e.message, 'Some items...');
    });

    test('ignores other 409s', () {
      expect(
          InsufficientStockException.tryParse(
              '{"message":"x","data":{"code":"STOCK_CHANGED"}}'),
          isNull);
      expect(InsufficientStockException.tryParse('not json'), isNull);
    });
  });
}
