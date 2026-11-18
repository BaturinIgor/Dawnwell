import { AppData } from '../types';

export type SnapshotReason = 'daily' | 'before-import' | 'before-restore' | 'upgrade';

export type SnapshotInfo = { id: number; takenAt: number; reason: SnapshotReason; dayCount: number };

/** `data` is null on a fresh install. `setAside` counts stored records that could not be read and were kept apart. */
export type LoadResult = { data: AppData | null; setAside: number };

/** How many snapshots to keep: one a day for a week, plus the latest safety copies. */
export const KEEP = { daily: 7, other: 5 };

export interface Storage {
  load(): Promise<LoadResult>;
  /** Write only what changed between the last saved state and the new one. */
  write(prev: AppData | null, next: AppData): Promise<void>;
  /** Replace everything, used by restore and import. */
  replaceAll(next: AppData): Promise<void>;
  snapshot(reason: SnapshotReason, data: AppData): Promise<void>;
  listSnapshots(): Promise<SnapshotInfo[]>;
  readSnapshot(id: number): Promise<AppData>;
}
