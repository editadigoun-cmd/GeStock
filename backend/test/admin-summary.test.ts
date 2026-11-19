import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import { summarizeSyncStatuses } from '../src/services/admin-summary.js';

test('admin sync summary counts known and unknown statuses without dropping records', () => {
  const summary = summarizeSyncStatuses([
    { status: 'queued', count: 2 },
    { status: 'applied', count: 5 },
    { status: 'conflict', count: 1 },
    { status: 'rejected', count: 3 },
    { status: 'unexpected', count: 4 },
  ]);
  assert.deepEqual(summary, {
    total: 15, queued: 2, applied: 5, conflict: 1, rejected: 3,
    failed: 0, processing: 0, other: 4,
  });
});
