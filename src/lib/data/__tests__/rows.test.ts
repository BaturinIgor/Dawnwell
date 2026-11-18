import { describe, expect, it } from '@jest/globals';

import { diffRows, fromRows, Row, toRows } from '../rows';
import { DATA_VERSION, NewerDataError } from '../schema';
import { sample } from './fixtures';

const asRows = (m: Map<string, string>): Row[] => [...m].map(([key, value]) => ({ key, value }));

describe('rows', () => {
  it('round-trips through rows without loss', () => {
    const d = sample();
    const { data, bad } = fromRows(asRows(toRows(d)));
    expect(bad).toEqual([]);
    expect(data).toEqual(d);
  });

  it('stores one row per day', () => {
    const keys = [...toRows(sample()).keys()];
    expect(keys).toEqual(expect.arrayContaining(['settings', 'day:2026-11-17', 'day:2026-11-18']));
  });

  it('writes only the day that changed', () => {
    const prev = sample();
    const next = { ...prev, days: { ...prev.days, '2026-11-18': { ...prev.days['2026-11-18'], water: 3 } } };
    const { upsert, remove } = diffRows(prev, next);
    expect(upsert.map((r) => r.key)).toEqual(['day:2026-11-18']);
    expect(remove).toEqual([]);
  });

  it('writes nothing when nothing changed', () => {
    const d = sample();
    expect(diffRows(d, d)).toEqual({ upsert: [], remove: [] });
  });

  it('writes everything on the first save', () => {
    const d = sample();
    expect(diffRows(null, d).upsert).toHaveLength(toRows(d).size);
  });

  it('removes a day that is gone', () => {
    const prev = sample();
    const { '2026-11-18': _gone, ...rest } = prev.days;
    expect(diffRows(prev, { ...prev, days: rest }).remove).toEqual(['day:2026-11-18']);
  });

  it('sets aside a damaged row and keeps everything else', () => {
    const rows = asRows(toRows(sample()));
    const broken = rows.map((r) => (r.key === 'day:2026-11-17' ? { ...r, value: '{"takenAt": 1, "foo' } : r));
    const { data, bad } = fromRows([...broken, { key: 'mystery', value: '1' }]);
    expect(bad.map((r) => r.key).sort()).toEqual(['day:2026-11-17', 'mystery']);
    expect(Object.keys(data.days)).toEqual(['2026-11-18']);
    expect(data.settings.doseLabel).toBe('7 mg');
    expect(data.weights).toHaveLength(2);
  });

  it('refuses rows written by a newer app', () => {
    const rows = asRows(toRows(sample())).map((r) => (r.key === 'version' ? { ...r, value: String(DATA_VERSION + 1) } : r));
    expect(() => fromRows(rows)).toThrow(NewerDataError);
  });
});
