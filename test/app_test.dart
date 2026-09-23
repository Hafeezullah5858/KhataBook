import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/main.dart';

void main() {
  test('income expense and profit calculation', () {
    final store = AppStore();

    store.tx.addAll([
      {'type': 'income', 'amount': 6000.0},
      {'type': 'expense', 'amount': 2500.0},
      {'type': 'expense', 'amount': 1000.0},
    ]);

    expect(store.income, 6000.0);
    expect(store.expense, 3500.0);
    expect(store.profit, 2500.0);
  });
}
