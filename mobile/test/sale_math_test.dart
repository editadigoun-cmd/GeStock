import 'package:flutter_test/flutter_test.dart';
import 'package:gestock/data/repositories/sale_math.dart';

void main() {
  test('calculates subtotal, discount, tax and total with cent rounding', () {
    final result = calculateSaleTotals([
      const SaleLineDraft(quantity: 2, unitPrice: 1250.25, discountAmount: 100, taxAmount: 0),
      const SaleLineDraft(quantity: 1.5, unitPrice: 500, taxAmount: 50),
    ]);
    expect(result.subtotal, 3250.5);
    expect(result.discountTotal, 100);
    expect(result.taxTotal, 50);
    expect(result.total, 3200.5);
  });

  test('rejects empty basket, zero quantity and excessive discount', () {
    expect(() => calculateSaleTotals([]), throwsArgumentError);
    expect(() => calculateSaleTotals([const SaleLineDraft(quantity: 0, unitPrice: 10)]), throwsArgumentError);
    expect(() => calculateSaleTotals([const SaleLineDraft(quantity: 1, unitPrice: 10, discountAmount: 11)]), throwsArgumentError);
  });
}
