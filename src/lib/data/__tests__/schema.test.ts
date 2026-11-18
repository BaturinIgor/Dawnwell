import { describe, expect, it } from '@jest/globals';

import { DATA_VERSION, defaultSettings, hasUserData, initialData, migrate, NewerDataError } from '../schema';
import { sample } from './fixtures';

describe('migrate', () => {
  it('keeps valid data exactly', () => {
    const d = sample();
    expect(migrate(JSON.parse(JSON.stringify(d)))).toEqual(d);
  });

  it('reads the blob saved by the first build, with fields missing', () => {
    const legacy = {
      version: 1,
      settings: { onboarded: true, doseLabel: '3 mg', reminders: { tablet: false } },
      days: { '2026-11-01': { takenAt: 123, foods: [{ name: 'Eggs', protein: 12 }] } },
    };
    const d = migrate(legacy);
    expect(d.version).toBe(DATA_VERSION);
    expect(d.settings.doseLabel).toBe('3 mg');
    expect(d.settings.waitMinutes).toBe(defaultSettings.waitMinutes);
    expect(d.settings.reminders).toEqual({ ...defaultSettings.reminders, tablet: false });
    expect(d.days['2026-11-01'].takenAt).toBe(123);
    expect(d.days['2026-11-01'].foods[0]).toMatchObject({ name: 'Eggs', protein: 12, meal: 'Snack' });
    expect(d.weights).toEqual([]);
    expect(d.questions).toBe('');
  });

  it('drops only the bad entries and keeps the rest', () => {
    const d = migrate({
      days: {
        '2026-11-02': { foods: [{ name: 'Tuna', protein: 27 }, { protein: 5 }, 'junk'], symptoms: [{ id: 'unknown' }, { id: 'fatigue', severity: 9 }] },
        'not-a-day': { water: 3 },
      },
      weights: [{ date: '2026-11-02', value: 190 }, { date: 'bad', value: 1 }, { date: '2026-11-03', value: -5 }],
    });
    expect(Object.keys(d.days)).toEqual(['2026-11-02']);
    expect(d.days['2026-11-02'].foods.map((f) => f.name)).toEqual(['Tuna']);
    expect(d.days['2026-11-02'].symptoms).toEqual([expect.objectContaining({ id: 'fatigue', severity: 5 })]);
    expect(d.weights).toEqual([{ date: '2026-11-02', value: 190 }]);
  });

  it('clamps settings that are out of range', () => {
    const d = migrate({ settings: { doseHour: 30, doseMinute: -4, waitMinutes: 'x', medication: 'pill' } });
    expect(d.settings.doseHour).toBe(23);
    expect(d.settings.doseMinute).toBe(0);
    expect(d.settings.waitMinutes).toBe(defaultSettings.waitMinutes);
    expect(d.settings.medication).toBe(defaultSettings.medication);
  });

  it('refuses data from a newer app instead of guessing', () => {
    expect(() => migrate({ version: DATA_VERSION + 1 })).toThrow(NewerDataError);
  });

  it('refuses something that is not data at all', () => {
    expect(() => migrate(null)).toThrow();
    expect(() => migrate([1, 2])).toThrow();
    expect(() => migrate('text')).toThrow();
  });
});

describe('hasUserData', () => {
  it('is false for a fresh install and true once anything is logged', () => {
    expect(hasUserData(initialData())).toBe(false);
    expect(hasUserData(sample())).toBe(true);
  });
});
