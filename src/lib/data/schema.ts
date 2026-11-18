/**
 * Shape checks and upgrades for stored data. Pure functions only, so they can be unit tested.
 *
 * Rule: never throw away a whole record because one part is bad. Bad entries are dropped
 * one by one, missing fields get defaults, and unknown fields are ignored.
 */
import { AppData, DayLog, DoseChange, FoodEntry, Meal, MedicationId, Reminders, Settings, SymptomEntry, SymptomId, WeightEntry } from '../types';

/** Bump when AppData changes shape, and add a step to `UPGRADES`. */
export const DATA_VERSION = 1;

const MEDS: MedicationId[] = ['oral-semaglutide', 'orforglipron', 'other'];
const MEALS: Meal[] = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
const SYMPTOM_IDS: SymptomId[] = ['nausea', 'constipation', 'heartburn', 'fatigue', 'no-appetite', 'good'];
const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

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

export const initialData = (): AppData => ({
  version: DATA_VERSION,
  settings: defaultSettings,
  days: {},
  weights: [],
  doseHistory: [],
  questions: '',
});

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => typeof v === 'object' && v !== null && !Array.isArray(v);
const num = (v: unknown, fallback: number, min = -Infinity, max = Infinity): number =>
  typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : fallback;
const numOrNull = (v: unknown, min = -Infinity, max = Infinity): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : null;
const str = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);
const bool = (v: unknown, fallback: boolean): boolean => (typeof v === 'boolean' ? v : fallback);
const oneOf = <T extends string>(v: unknown, options: T[], fallback: T): T =>
  options.includes(v as T) ? (v as T) : fallback;
const list = <T>(v: unknown, item: (x: unknown) => T | null): T[] =>
  Array.isArray(v) ? v.map(item).filter((x): x is T => x !== null) : [];

export function normalizeSettings(v: unknown): Settings {
  const s = isObj(v) ? v : {};
  const r = isObj(s.reminders) ? s.reminders : {};
  const d = defaultSettings;
  const reminders: Reminders = {
    tablet: bool(r.tablet, d.reminders.tablet),
    waitOver: bool(r.waitOver, d.reminders.waitOver),
    protein: bool(r.protein, d.reminders.protein),
    refill: bool(r.refill, d.reminders.refill),
  };
  return {
    onboarded: bool(s.onboarded, d.onboarded),
    medication: oneOf(s.medication, MEDS, d.medication),
    doseLabel: str(s.doseLabel),
    doseHour: Math.round(num(s.doseHour, d.doseHour, 0, 23)),
    doseMinute: Math.round(num(s.doseMinute, d.doseMinute, 0, 59)),
    waitMinutes: num(s.waitMinutes, d.waitMinutes, 0, 240),
    proteinTarget: num(s.proteinTarget, d.proteinTarget, 0, 500),
    fiberTarget: num(s.fiberTarget, d.fiberTarget, 0, 200),
    waterTarget: num(s.waterTarget, d.waterTarget, 0, 40),
    startWeight: numOrNull(s.startWeight, 0),
    goalWeight: numOrNull(s.goalWeight, 0),
    tabletsLeft: numOrNull(s.tabletsLeft, 0),
    reminders,
  };
}

function food(v: unknown): FoodEntry | null {
  if (!isObj(v) || typeof v.name !== 'string') return null;
  return {
    id: str(v.id, `${num(v.at, 0)}-${v.name}`),
    name: v.name,
    protein: num(v.protein, 0, 0, 1000),
    meal: oneOf(v.meal, MEALS, 'Snack'),
    at: num(v.at, 0),
  };
}

function symptom(v: unknown): SymptomEntry | null {
  if (!isObj(v) || !SYMPTOM_IDS.includes(v.id as SymptomId)) return null;
  return {
    id: v.id as SymptomId,
    severity: Math.round(num(v.severity, 2, 1, 5)),
    triggers: list(v.triggers, (t) => (typeof t === 'string' ? t : null)),
    note: str(v.note),
    at: num(v.at, 0),
  };
}

export function normalizeDay(v: unknown): DayLog {
  const d = isObj(v) ? v : {};
  return {
    takenAt: numOrNull(d.takenAt, 0),
    skipped: bool(d.skipped, false),
    water: num(d.water, 0, 0, 100),
    fiber: num(d.fiber, 0, 0, 500),
    foodNoise: d.foodNoise === null ? null : numOrNull(d.foodNoise, 1, 5),
    foods: list(d.foods, food),
    symptoms: list(d.symptoms, symptom),
    strength: num(d.strength, 0, 0, 1000),
  };
}

export function normalizeWeights(v: unknown): WeightEntry[] {
  return list(v, (w) =>
    isObj(w) && typeof w.date === 'string' && DAY_KEY.test(w.date) && typeof w.value === 'number' && w.value > 0
      ? { date: w.date, value: w.value }
      : null,
  );
}

export function normalizeDoseHistory(v: unknown): DoseChange[] {
  return list(v, (x) =>
    isObj(x) && typeof x.label === 'string' && typeof x.from === 'string' ? { label: x.label, from: x.from } : null,
  );
}

export const isDayKey = (k: string) => DAY_KEY.test(k);

/**
 * Upgrade steps, keyed by the version they upgrade FROM. Each takes the raw object of that
 * version and returns the raw object of the next one. None yet: version 1 is the first.
 */
const UPGRADES: Record<number, (raw: Obj) => Obj> = {};

export class NewerDataError extends Error {
  constructor(public found: number) {
    super(`Data was saved by a newer version of the app (data version ${found}).`);
  }
}

/**
 * Turn anything read from storage or a backup file into valid AppData.
 * Throws only when the input is not an object at all, or was written by a newer app,
 * so callers can keep the original instead of overwriting it.
 */
export function migrate(input: unknown): AppData {
  if (!isObj(input)) throw new Error('Not a Dawnwell data object');
  let raw: Obj = input;
  let version = typeof raw.version === 'number' ? raw.version : 1;
  if (version > DATA_VERSION) throw new NewerDataError(version);
  while (version < DATA_VERSION) {
    const step = UPGRADES[version];
    if (!step) throw new Error(`No upgrade from data version ${version}`);
    raw = step(raw);
    version += 1;
  }
  const days: Record<string, DayLog> = {};
  if (isObj(raw.days)) {
    for (const [k, v] of Object.entries(raw.days)) if (isDayKey(k) && isObj(v)) days[k] = normalizeDay(v);
  }
  return {
    version: DATA_VERSION,
    settings: normalizeSettings(raw.settings),
    days,
    weights: normalizeWeights(raw.weights),
    doseHistory: normalizeDoseHistory(raw.doseHistory),
    questions: str(raw.questions),
  };
}

/** True when the user has logged anything worth protecting. */
export function hasUserData(d: AppData): boolean {
  return d.settings.onboarded || Object.keys(d.days).length > 0 || d.weights.length > 0;
}
