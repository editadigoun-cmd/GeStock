import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calculateSaleTotals } from '../src/services/sale-math.js';

test('calculates rounded totals, discounts and taxes', () => {
  const totals = calculateSaleTotals([
    { quantity: 2, unit_price: 1250.25, discount_amount: 100 },
    { quantity: 1.5, unit_price: 500, tax_amount: 50 },
  ]);
  assert.deepEqual(totals, { subtotal: 3250.5, discount_total: 100, tax_total: 50, total: 3200.5, lines: [{ line_total: 2400.5 }, { line_total: 800 }] });
});

test('rejects invalid quantities and discounts', () => {
  assert.throws(() => calculateSaleTotals([]), /SALE_EMPTY/);
  assert.throws(() => calculateSaleTotals([{ quantity: 0, unit_price: 10 }]), /INVALID_SALE_LINE/);
  assert.throws(() => calculateSaleTotals([{ quantity: 1, unit_price: 10, discount_amount: 11 }]), /INVALID_SALE_LINE/);
});
