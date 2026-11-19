export type SyncStatusCount = { status: string; count: number };

export function summarizeSyncStatuses(rows: SyncStatusCount[]) {
  const summary: Record<string, number> = {
    total: 0, queued: 0, applied: 0, conflict: 0, rejected: 0, failed: 0, processing: 0, other: 0,
  };
  for (const row of rows) {
    const count = Number(row.count) || 0;
    summary.total += count;
    if (Object.prototype.hasOwnProperty.call(summary, row.status)) summary[row.status] += count;
    else summary.other += count;
  }
  return summary;
}
