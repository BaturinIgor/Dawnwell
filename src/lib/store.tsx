import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { AppState } from 'react-native';

import { storage } from './data/db';
import { emptyDay, initialData, NewerDataError } from './data/schema';
import { SnapshotInfo } from './data/storage-types';
import { dayKey } from './date';
import { AppData, DayLog, Settings } from './types';

export { defaultSettings, emptyDay } from './data/schema';

const SAVE_DELAY = 250;

/**
 * - `ok`: loaded and saving.
 * - `newer`: data was written by a newer app version. We show it read-only and never write.
 * - `failed`: storage could not be opened. We do not write, so nothing on disk is overwritten.
 */
export type StorageStatus = 'loading' | 'ok' | 'newer' | 'failed';

type Store = {
  ready: boolean;
  status: StorageStatus;
  /** Stored records that could not be read on this launch and were kept apart. */
  setAside: number;
  data: AppData;
  update: (fn: (d: AppData) => AppData) => void;
  updateDay: (key: string, fn: (day: DayLog) => DayLog) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  /** Write pending changes now. */
  flush: () => Promise<void>;
  listSnapshots: () => Promise<SnapshotInfo[]>;
  /** Replace all data with a snapshot, keeping a copy of the current data first. */
  restoreSnapshot: (id: number) => Promise<void>;
  /** Replace all data with imported data, keeping a copy of the current data first. */
  replaceWith: (next: AppData) => Promise<void>;
};

const StoreContext = createContext<Store | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AppData>(initialData);
  const [status, setStatus] = useState<StorageStatus>('loading');
  const [setAside, setSetAside] = useState(0);

  // What is known to be on disk. Diffs are taken against it; it only moves after a write succeeds.
  const saved = useRef<AppData | null>(null);
  const latest = useRef<AppData>(data);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Writes run one after another, never overlapping.
  const queue = useRef<Promise<void>>(Promise.resolve());
  const canWrite = status === 'ok';

  useEffect(() => {
    latest.current = data;
  }, [data]);

  useEffect(() => {
    let alive = true;
    storage
      .load()
      .then(async ({ data: loaded, setAside: aside }) => {
        if (!alive) return;
        if (loaded) {
          saved.current = loaded;
          latest.current = loaded;
          setData(loaded);
          await takeDailySnapshot(loaded).catch(() => {});
        }
        setSetAside(aside);
        setStatus('ok');
      })
      .catch((e) => {
        if (alive) setStatus(e instanceof NewerDataError ? 'newer' : 'failed');
      });
    return () => {
      alive = false;
    };
  }, []);

  const flush = useCallback(() => {
    if (timer.current) {
      clearTimeout(timer.current);
      timer.current = null;
    }
    if (!canWrite) return queue.current;
    queue.current = queue.current.then(async () => {
      const next = latest.current;
      if (next === saved.current) return;
      try {
        await storage.write(saved.current, next);
        saved.current = next;
      } catch {
        // Keep `saved` as it was so the next flush retries the same changes.
      }
    });
    return queue.current;
  }, [canWrite]);

  // Save shortly after each change.
  useEffect(() => {
    if (!canWrite || data === saved.current) return;
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      flush();
    }, SAVE_DELAY);
  }, [data, canWrite, flush]);

  // Save at once when the app goes to the background, where it may be killed.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (s) => {
      if (s !== 'active') flush();
    });
    return () => sub.remove();
  }, [flush]);

  const update = useCallback((fn: (d: AppData) => AppData) => setData((d) => fn(d)), []);

  const updateDay = useCallback(
    (key: string, fn: (day: DayLog) => DayLog) =>
      setData((d) => ({ ...d, days: { ...d.days, [key]: fn(d.days[key] ?? emptyDay()) } })),
    [],
  );

  const updateSettings = useCallback(
    (patch: Partial<Settings>) => setData((d) => ({ ...d, settings: { ...d.settings, ...patch } })),
    [],
  );

  const replace = useCallback(
    async (next: AppData, reason: 'before-import' | 'before-restore') => {
      if (!canWrite) throw new Error('Storage is not writable');
      await flush();
      await storage.snapshot(reason, latest.current);
      await storage.replaceAll(next);
      saved.current = next;
      latest.current = next;
      setData(next);
    },
    [canWrite, flush],
  );

  const restoreSnapshot = useCallback(
    async (id: number) => replace(await storage.readSnapshot(id), 'before-restore'),
    [replace],
  );
  const replaceWith = useCallback((next: AppData) => replace(next, 'before-import'), [replace]);
  const listSnapshots = useCallback(() => storage.listSnapshots(), []);

  const value = useMemo(
    () => ({
      ready: status !== 'loading',
      status,
      setAside,
      data,
      update,
      updateDay,
      updateSettings,
      flush,
      listSnapshots,
      restoreSnapshot,
      replaceWith,
    }),
    [status, setAside, data, update, updateDay, updateSettings, flush, listSnapshots, restoreSnapshot, replaceWith],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

/** One local copy per calendar day, taken on the first launch of the day. */
async function takeDailySnapshot(d: AppData) {
  const list = await storage.listSnapshots();
  const lastDaily = list.find((s) => s.reason === 'daily');
  if (lastDaily && dayKey(new Date(lastDaily.takenAt)) === dayKey()) return;
  await storage.snapshot('daily', d);
}

export function useStore(): Store {
  const s = useContext(StoreContext);
  if (!s) throw new Error('useStore must be used inside StoreProvider');
  return s;
}

export function useDay(key: string = dayKey()): DayLog {
  const { data } = useStore();
  return data.days[key] ?? emptyDay();
}

export function proteinOf(day: DayLog): number {
  return day.foods.reduce((sum, f) => sum + f.protein, 0);
}

export function newId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}
