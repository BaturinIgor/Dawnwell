import { AppData } from '../../types';
import { initialData } from '../schema';

export function sample(): AppData {
  const d = initialData();
  return {
    ...d,
    settings: { ...d.settings, onboarded: true, doseLabel: '7 mg', startWeight: 195, goalWeight: 170, tabletsLeft: 20 },
    days: {
      '2026-11-17': {
        takenAt: 1_763_360_000_000,
        skipped: false,
        water: 6,
        fiber: 12,
        foodNoise: 3,
        foods: [{ id: 'a', name: 'Greek yogurt', protein: 17, meal: 'Breakfast', at: 1_763_362_000_000 }],
        symptoms: [{ id: 'nausea', severity: 2, triggers: ['Fatty food'], note: 'after dinner', at: 1_763_390_000_000 }],
        strength: 1,
      },
      '2026-11-18': {
        takenAt: null,
        skipped: true,
        water: 2,
        fiber: 0,
        foodNoise: null,
        foods: [],
        symptoms: [],
        strength: 0,
      },
    },
    weights: [
      { date: '2026-11-10', value: 195 },
      { date: '2026-11-17', value: 193.4 },
    ],
    doseHistory: [{ label: '7 mg daily', from: '2026-11-10' }],
    questions: 'Is nausea after dinner normal?',
  };
}
