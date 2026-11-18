import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';

import { dayKey } from './date';
import { AppData, DayLog, Settings } from './types';

const STORAGE_KEY = 'app-data-v1';

export const defaultSettings: Settings = {
  onboarded: false,
  medication: 'oral-semaglutide',
  doseLabel: '',
  doseHour: 7,
  doseMinute: 0,
  waitMinutes: 30,
  proteinTarget: 100,
  fiberTarget: 25,
  waterTarget: 8,
  startWeight: null,
  goalWeight: null,
  tabletsLeft: null,
  reminders: { tablet: true, waitOver: true, protein: true, refill: false },
};

export const emptyDay = (): DayLog => ({
  takenAt: null,
  skipped: false,
  water: 0,
  fiber: 0,
  foodNoise: null,
  foods: [],
  symptoms: [],
  strength: 0,
});

const initialData = (): AppData => ({
  version: 1,
  settings: defaultSettings,
  days: {},
  weights: [],
  doseHistory: [],
  questions: '',
});

type Store = {
  ready: boolean;
  data: AppData;
  update: (fn: (d: AppData) => AppData) => void;
  updateDay: (key: string, fn: (day: DayLog) => DayLog) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  reset: () => void;
};

const StoreContext = createContext<Store | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AppData>(initialData);
  const [ready, setReady] = useState(false);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY)
      .then((raw) => {
        if (!raw) return;
        const parsed = JSON.parse(raw) as AppData;
        setData({
          ...initialData(),
          ...parsed,
          settings: {
            ...defaultSettings,
            ...parsed.settings,
            reminders: { ...defaultSettings.reminders, ...parsed.settings?.reminders },
          },
        });
      })
      .catch(() => {
        // Corrupt or unreadable data: start fresh rather than crash.
      })
      .finally(() => setReady(true));
  }, []);

  useEffect(() => {
    if (!ready) return;
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data)).catch(() => {});
    }, 300);
  }, [data, ready]);

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

  const reset = useCallback(() => setData(initialData()), []);

  const value = useMemo(
    () => ({ ready, data, update, updateDay, updateSettings, reset }),
    [ready, data, update, updateDay, updateSettings, reset],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
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
