import { describe, expect, it } from '@jest/globals';

import { backupFileName, BackupError, makeBackup, parseBackup } from '../backup';
import { DATA_VERSION } from '../schema';
import { sample } from './fixtures';

describe('backup file', () => {
  it('restores exactly what was saved', () => {
    const d = sample();
    const at = new Date('2026-11-18T09:00:00Z');
    const { data, exportedAt } = parseBackup(makeBackup(d, at));
    expect(data).toEqual(d);
    expect(exportedAt).toBe('2026-11-18T09:00:00.000Z');
  });

  it('rejects files that are not Dawnwell backups', () => {
    expect(() => parseBackup('hello')).toThrow(BackupError);
    expect(() => parseBackup('{"settings":{}}')).toThrow("isn't a Dawnwell backup");
  });

  it('explains a backup from a newer app', () => {
    const file = JSON.stringify({ format: 'dawnwell-backup', data: { version: DATA_VERSION + 1 } });
    expect(() => parseBackup(file)).toThrow(/newer version/);
  });

  it('rejects a damaged backup', () => {
    expect(() => parseBackup('{"format":"dawnwell-backup","data":null}')).toThrow(/damaged/);
  });

  it('names the file by date', () => {
    expect(backupFileName(new Date('2026-11-18T09:00:00Z'))).toBe('dawnwell-backup-2026-11-18.json');
  });
});
