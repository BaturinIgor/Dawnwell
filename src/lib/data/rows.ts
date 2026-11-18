/**
 * AppData is stored as one row per section and one row per day, so a write touches only
 * what changed and one bad row can never take the rest of the data with it.
 */
import { AppData } from '../types';
import { isDayKey, migrate } from './schema';

export type Row = { key: string; value: string };

const DAY_PREFIX = 'day:';

export function toRows(d: AppData): Map<string, string> {
  const rows = new Map<string, string>();
  rows.set('version', JSON.stringify(d.version));
  rows.set('settings', JSON.stringify(d.settings));
  rows.set('weights', JSON.stringify(d.weights));
  rows.set('doseHistory', JSON.stringify(d.doseHistory));
  rows.set('questions', JSON.stringify(d.questions));
  for (const [k, day] of Object.entries(d.days)) rows.set(DAY_PREFIX + k, JSON.stringify(day));
  return rows;
}

/** Rows that differ between two states. Sections that are the same object are skipped without serializing. */
export function diffRows(prev: AppData | null, next: AppData): { upsert: Row[]; remove: string[] } {
  if (!prev) return { upsert: [...toRows(next)].map(([key, value]) => ({ key, value })), remove: [] };
  const upsert: Row[] = [];
  const put = (key: string, value: unknown) => upsert.push({ key, value: JSON.stringify(value) });
  if (prev.version !== next.version) put('version', next.version);
  if (prev.settings !== next.settings) put('settings', next.settings);
  if (prev.weights !== next.weights) put('weights', next.weights);
  if (prev.doseHistory !== next.doseHistory) put('doseHistory', next.doseHistory);
  if (prev.questions !== next.questions) put('questions', next.questions);
  if (prev.days !== next.days) {
    for (const [k, day] of Object.entries(next.days)) if (prev.days[k] !== day) put(DAY_PREFIX + k, day);
  }
  const remove = prev.days === next.days ? [] : Object.keys(prev.days).filter((k) => !(k in next.days)).map((k) => DAY_PREFIX + k);
  return { upsert, remove };
}

/**
 * Rebuild AppData from rows. Rows that can't be read are returned in `bad` untouched,
 * so the caller can set them aside instead of losing them. Older data versions are
 * upgraded through `migrate`; data from a newer app throws `NewerDataError`.
 */
export function fromRows(rows: Row[]): { data: AppData; bad: Row[] } {
  const bad: Row[] = [];
  const raw: Record<string, unknown> = {};
  const days: Record<string, unknown> = {};
  for (const row of rows) {
    let v: unknown;
    try {
      v = JSON.parse(row.value);
    } catch {
      bad.push(row);
      continue;
    }
    if (SECTIONS.includes(row.key)) raw[row.key] = v;
    else if (row.key.startsWith(DAY_PREFIX) && isDayKey(row.key.slice(DAY_PREFIX.length)) && isRecord(v))
      days[row.key.slice(DAY_PREFIX.length)] = v;
    else bad.push(row);
  }
  raw.days = days;
  return { data: migrate(raw), bad };
}

const SECTIONS = ['version', 'settings', 'weights', 'doseHistory', 'questions'];
const isRecord = (v: unknown) => typeof v === 'object' && v !== null && !Array.isArray(v);

/** The data version recorded in the rows, or null when there is none. */
export function rowsVersion(rows: Row[]): number | null {
  const r = rows.find((x) => x.key === 'version');
  if (!r) return null;
  try {
    const v = JSON.parse(r.value);
    return typeof v === 'number' ? v : null;
  } catch {
    return null;
  }
}
