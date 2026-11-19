class SaleLineDraft {
  const SaleLineDraft({required this.quantity, required this.unitPrice, this.discountAmount = 0, this.taxAmount = 0});
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxAmount;
}

class SaleTotals {
  const SaleTotals({required this.subtotal, required this.discountTotal, required this.taxTotal, required this.total});
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
}

double roundMoney(double value) => (value * 100).roundToDouble() / 100;

SaleTotals calculateSaleTotals(List<SaleLineDraft> lines) {
  if (lines.isEmpty) throw ArgumentError('Le panier est vide.');
  var subtotal = 0.0;
  var discountTotal = 0.0;
  var taxTotal = 0.0;
  for (final line in lines) {
    if (!line.quantity.isFinite || line.quantity <= 0 ||
        !line.unitPrice.isFinite || line.unitPrice < 0) {
      throw ArgumentError('Quantité ou prix invalide.');
    }
    final gross = roundMoney(line.quantity * line.unitPrice);
    final discount = roundMoney(line.discountAmount);
    final tax = roundMoney(line.taxAmount);
    if (discount < 0 || discount > gross || tax < 0) {
      throw ArgumentError('Remise ou taxe invalide.');
    }
    subtotal += gross;
    discountTotal += discount;
    taxTotal += tax;
  }
  subtotal = roundMoney(subtotal);
  discountTotal = roundMoney(discountTotal);
  taxTotal = roundMoney(taxTotal);
  return SaleTotals(
    subtotal: subtotal,
    discountTotal: discountTotal,
    taxTotal: taxTotal,
    total: roundMoney(subtotal - discountTotal + taxTotal),
  );
}
