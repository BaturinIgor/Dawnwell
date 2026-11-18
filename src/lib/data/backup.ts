/** Backup file format. Pure functions, so they can be unit tested. */
import { AppData } from '../types';
import { DATA_VERSION, migrate, NewerDataError } from './schema';

const MARK = 'dawnwell-backup';

export function makeBackup(data: AppData, now: Date = new Date()): string {
  return JSON.stringify({ format: MARK, formatVersion: 1, dataVersion: DATA_VERSION, exportedAt: now.toISOString(), data }, null, 1);
}

export class BackupError extends Error {}

/** Read a backup file. Throws BackupError with a message fit to show the user. */
export function parseBackup(text: string): { data: AppData; exportedAt: string | null } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new BackupError("This file isn't a Dawnwell backup.");
  }
  if (typeof parsed !== 'object' || parsed === null || (parsed as { format?: unknown }).format !== MARK) {
    throw new BackupError("This file isn't a Dawnwell backup.");
  }
  const p = parsed as { data?: unknown; exportedAt?: unknown };
  try {
    return { data: migrate(p.data), exportedAt: typeof p.exportedAt === 'string' ? p.exportedAt : null };
  } catch (e) {
    if (e instanceof NewerDataError) {
      throw new BackupError('This backup was made by a newer version of Dawnwell. Update the app, then try again.');
    }
    throw new BackupError("This backup file is damaged and can't be read.");
  }
}

export function backupFileName(now: Date = new Date()): string {
  const d = now.toISOString().slice(0, 10);
  return `dawnwell-backup-${d}.json`;
}

/** Short description of what a data set holds, for confirmations. */
export function describe(d: AppData): string {
  const days = Object.keys(d.days).length;
  const weights = d.weights.length;
  return `${days} day${days === 1 ? '' : 's'} of logs, ${weights} weight entr${weights === 1 ? 'y' : 'ies'}`;
}
