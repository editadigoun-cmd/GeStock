export type SaleLineMath = { quantity: number; unit_price: number; discount_amount?: number; tax_amount?: number };
export type SaleTotals = { subtotal: number; discount_total: number; tax_total: number; total: number; lines: { line_total: number }[] };

export function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function calculateSaleTotals(lines: SaleLineMath[]): SaleTotals {
  if (!lines.length) throw new Error('SALE_EMPTY');
  let subtotal = 0;
  let discountTotal = 0;
  let taxTotal = 0;
  const normalized = lines.map((line) => {
    if (!Number.isFinite(line.quantity) || line.quantity <= 0 ||
        !Number.isFinite(line.unit_price) || line.unit_price < 0) throw new Error('INVALID_SALE_LINE');
    const gross = roundMoney(line.quantity * line.unit_price);
    const discount = roundMoney(line.discount_amount ?? 0);
    const tax = roundMoney(line.tax_amount ?? 0);
    if (discount < 0 || discount > gross || tax < 0) throw new Error('INVALID_SALE_LINE');
    subtotal += gross;
    discountTotal += discount;
    taxTotal += tax;
    return { line_total: roundMoney(gross - discount + tax) };
  });
  subtotal = roundMoney(subtotal);
  discountTotal = roundMoney(discountTotal);
  taxTotal = roundMoney(taxTotal);
  return { subtotal, discount_total: discountTotal, tax_total: taxTotal, total: roundMoney(subtotal - discountTotal + taxTotal), lines: normalized };
}
