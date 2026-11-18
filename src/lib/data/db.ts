/**
 * On-device storage in SQLite. Writes are transactional, so a crash mid-write leaves the
 * previous state intact. Nothing in here ever deletes user rows it could not read: they
 * are moved to `set_aside` and kept.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SQLite from 'expo-sqlite';

import { AppData } from '../types';
import { diffRows, fromRows, Row, rowsVersion, toRows } from './rows';
import { DATA_VERSION, hasUserData, migrate, NewerDataError } from './schema';
import { KEEP, LoadResult, SnapshotInfo, SnapshotReason, Storage } from './storage-types';

const LEGACY_KEY = 'app-data-v1';

type Tx = Parameters<Parameters<SQLite.SQLiteDatabase['withExclusiveTransactionAsync']>[0]>[0];

/** Table layout versions. Append only; never edit a step that has shipped. */
const SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS rows (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL, updated_at INTEGER NOT NULL);
   CREATE TABLE IF NOT EXISTS snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, taken_at INTEGER NOT NULL, reason TEXT NOT NULL, day_count INTEGER NOT NULL, data TEXT NOT NULL);
   CREATE TABLE IF NOT EXISTS set_aside (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT NOT NULL, at INTEGER NOT NULL);
   CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);`,
];

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

function db(): Promise<SQLite.SQLiteDatabase> {
  if (!dbPromise) {
    dbPromise = (async () => {
      const conn = await SQLite.openDatabaseAsync('dawnwell.db');
      await conn.execAsync('PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL;');
      const row = await conn.getFirstAsync<{ user_version: number }>('PRAGMA user_version');
      const current = row?.user_version ?? 0;
      for (let v = current; v < SCHEMA.length; v++) {
        await conn.withExclusiveTransactionAsync(async (tx) => {
          await tx.execAsync(SCHEMA[v]);
          await tx.execAsync(`PRAGMA user_version = ${v + 1}`);
        });
      }
      return conn;
    })().catch((e) => {
      dbPromise = null;
      throw e;
    });
  }
  return dbPromise;
}

async function getMeta(conn: SQLite.SQLiteDatabase, key: string): Promise<string | null> {
  const r = await conn.getFirstAsync<{ value: string }>('SELECT value FROM meta WHERE key = ?', key);
  return r?.value ?? null;
}

async function setMeta(conn: SQLite.SQLiteDatabase | Tx, key: string, value: string) {
  await conn.runAsync('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, value);
}

async function writeAll(tx: Tx, rows: Map<string, string>, at: number) {
  for (const [key, value] of rows) {
    await tx.runAsync(
      'INSERT INTO rows (key, value, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
      key,
      value,
      at,
    );
  }
}

/**
 * Bring over data saved by the first build (one JSON blob in AsyncStorage).
 * The old blob is left in place as a fallback.
 */
async function importLegacy(conn: SQLite.SQLiteDatabase): Promise<void> {
  if (await getMeta(conn, 'legacy_imported')) return;
  const raw = await AsyncStorage.getItem(LEGACY_KEY).catch(() => null);
  await conn.withExclusiveTransactionAsync(async (tx) => {
    const existing = await tx.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM rows');
    if (raw && (existing?.n ?? 0) === 0) {
      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        parsed = undefined;
      }
      let data: AppData | null = null;
      try {
        data = parsed === undefined ? null : migrate(parsed);
      } catch {
        data = null;
      }
      if (data) await writeAll(tx, toRows(data), Date.now());
      else await tx.runAsync('INSERT INTO set_aside (key, value, at) VALUES (?, ?, ?)', LEGACY_KEY, raw, Date.now());
    }
    await setMeta(tx, 'legacy_imported', String(Date.now()));
  });
}

async function setAside(conn: SQLite.SQLiteDatabase, bad: Row[]) {
  if (bad.length === 0) return;
  const at = Date.now();
  await conn.withExclusiveTransactionAsync(async (tx) => {
    for (const r of bad) {
      await tx.runAsync('INSERT INTO set_aside (key, value, at) VALUES (?, ?, ?)', r.key, r.value, at);
      await tx.runAsync('DELETE FROM rows WHERE key = ?', r.key);
    }
  });
}

async function prune(tx: Tx) {
  await tx.runAsync(
    `DELETE FROM snapshots WHERE reason = 'daily' AND id NOT IN (SELECT id FROM snapshots WHERE reason = 'daily' ORDER BY taken_at DESC LIMIT ?)`,
    KEEP.daily,
  );
  await tx.runAsync(
    `DELETE FROM snapshots WHERE reason != 'daily' AND id NOT IN (SELECT id FROM snapshots WHERE reason != 'daily' ORDER BY taken_at DESC LIMIT ?)`,
    KEEP.other,
  );
}

export const storage: Storage = {
  async load(): Promise<LoadResult> {
    const conn = await db();
    await importLegacy(conn);
    const rows = await conn.getAllAsync<Row>('SELECT key, value FROM rows');
    if (rows.length === 0) return { data: null, setAside: 0 };
    const version = rowsVersion(rows);
    if (version !== null && version > DATA_VERSION) throw new NewerDataError(version);
    if (version !== null && version < DATA_VERSION) {
      // Keep a copy in the old shape before the upgrade is written back.
      const before = JSON.stringify(Object.fromEntries(rows.map((r) => [r.key, r.value])));
      await conn.runAsync(
        'INSERT INTO snapshots (taken_at, reason, day_count, data) VALUES (?, ?, ?, ?)',
        Date.now(),
        'upgrade',
        rows.filter((r) => r.key.startsWith('day:')).length,
        before,
      );
    }
    const { data, bad } = fromRows(rows);
    await setAside(conn, bad);
    return { data, setAside: bad.length };
  },

  async write(prev, next) {
    const { upsert, remove } = diffRows(prev, next);
    if (upsert.length === 0 && remove.length === 0) return;
    const conn = await db();
    const at = Date.now();
    await conn.withExclusiveTransactionAsync(async (tx) => {
      await writeAll(tx, new Map(upsert.map((r) => [r.key, r.value])), at);
      for (const key of remove) await tx.runAsync('DELETE FROM rows WHERE key = ?', key);
    });
  },

  async replaceAll(next) {
    const conn = await db();
    await conn.withExclusiveTransactionAsync(async (tx) => {
      await tx.runAsync('DELETE FROM rows');
      await writeAll(tx, toRows(next), Date.now());
    });
  },

  async snapshot(reason: SnapshotReason, data: AppData) {
    if (!hasUserData(data)) return;
    const conn = await db();
    await conn.withExclusiveTransactionAsync(async (tx) => {
      await tx.runAsync(
        'INSERT INTO snapshots (taken_at, reason, day_count, data) VALUES (?, ?, ?, ?)',
        Date.now(),
        reason,
        Object.keys(data.days).length,
        JSON.stringify(data),
      );
      await prune(tx);
    });
  },

  async listSnapshots(): Promise<SnapshotInfo[]> {
    const conn = await db();
    const rows = await conn.getAllAsync<{ id: number; taken_at: number; reason: string; day_count: number }>(
      `SELECT id, taken_at, reason, day_count FROM snapshots WHERE reason != 'upgrade' ORDER BY taken_at DESC`,
    );
    return rows.map((r) => ({ id: r.id, takenAt: r.taken_at, reason: r.reason as SnapshotReason, dayCount: r.day_count }));
  },

  async readSnapshot(id: number): Promise<AppData> {
    const conn = await db();
    const r = await conn.getFirstAsync<{ data: string }>('SELECT data FROM snapshots WHERE id = ?', id);
    if (!r) throw new Error('Snapshot not found');
    return migrate(JSON.parse(r.data));
  },
};
