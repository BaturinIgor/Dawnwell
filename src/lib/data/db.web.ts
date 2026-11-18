/**
 * Web stand-in for the SQLite storage, used only for previews in a browser.
 * Same row layout, kept in localStorage.
 */
import { AppData } from '../types';
import { diffRows, fromRows, Row, rowsVersion, toRows } from './rows';
import { DATA_VERSION, hasUserData, migrate, NewerDataError } from './schema';
import { KEEP, LoadResult, SnapshotInfo, SnapshotReason, Storage } from './storage-types';

const ROW = 'dw:row:';
const SNAPS = 'dw:snapshots';
const ASIDE = 'dw:set-aside';

type Snap = SnapshotInfo & { data: string };

const ls = () => globalThis.localStorage;

function readRows(): Row[] {
  const out: Row[] = [];
  for (let i = 0; i < ls().length; i++) {
    const k = ls().key(i);
    if (k?.startsWith(ROW)) out.push({ key: k.slice(ROW.length), value: ls().getItem(k) ?? '' });
  }
  return out;
}

function readSnaps(): Snap[] {
  try {
    return JSON.parse(ls().getItem(SNAPS) ?? '[]') as Snap[];
  } catch {
    return [];
  }
}

export const storage: Storage = {
  async load(): Promise<LoadResult> {
    const rows = readRows();
    if (rows.length === 0) return { data: null, setAside: 0 };
    const version = rowsVersion(rows);
    if (version !== null && version > DATA_VERSION) throw new NewerDataError(version);
    const { data, bad } = fromRows(rows);
    if (bad.length) {
      const aside = JSON.parse(ls().getItem(ASIDE) ?? '[]') as Row[];
      ls().setItem(ASIDE, JSON.stringify([...aside, ...bad]));
      for (const r of bad) ls().removeItem(ROW + r.key);
    }
    return { data, setAside: bad.length };
  },
  async write(prev, next) {
    const { upsert, remove } = diffRows(prev, next);
    for (const r of upsert) ls().setItem(ROW + r.key, r.value);
    for (const k of remove) ls().removeItem(ROW + k);
  },
  async replaceAll(next) {
    for (const r of readRows()) ls().removeItem(ROW + r.key);
    for (const [k, v] of toRows(next)) ls().setItem(ROW + k, v);
  },
  async snapshot(reason: SnapshotReason, data: AppData) {
    if (!hasUserData(data)) return;
    const all = [
      { id: Date.now(), takenAt: Date.now(), reason, dayCount: Object.keys(data.days).length, data: JSON.stringify(data) },
      ...readSnaps(),
    ];
    const daily = all.filter((s) => s.reason === 'daily').slice(0, KEEP.daily);
    const other = all.filter((s) => s.reason !== 'daily').slice(0, KEEP.other);
    ls().setItem(SNAPS, JSON.stringify([...daily, ...other].sort((a, b) => b.takenAt - a.takenAt)));
  },
  async listSnapshots() {
    return readSnaps().map(({ data: _data, ...info }) => info);
  },
  async readSnapshot(id: number) {
    const s = readSnaps().find((x) => x.id === id);
    if (!s) throw new Error('Snapshot not found');
    return migrate(JSON.parse(s.data));
  },
};
