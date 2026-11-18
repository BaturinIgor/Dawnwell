import { MedicationId, SymptomId } from './types';

export const MEDICATIONS: { id: MedicationId; label: string }[] = [
  { id: 'oral-semaglutide', label: 'Oral semaglutide' },
  { id: 'orforglipron', label: 'Orforglipron' },
  { id: 'other', label: 'Another GLP-1 tablet' },
];

export const medicationLabel = (id: MedicationId) => MEDICATIONS.find((m) => m.id === id)?.label ?? 'GLP-1 tablet';

/** Typical protein per common portion (USDA values, rounded). */
export const FOODS: { name: string; portion: string; protein: number }[] = [
  { name: 'Greek yogurt, plain', portion: '3/4 cup · 170 g', protein: 17 },
  { name: 'Eggs', portion: '2 large', protein: 12 },
  { name: 'Protein shake', portion: '1 bottle', protein: 30 },
  { name: 'Cottage cheese', portion: '1/2 cup', protein: 14 },
  { name: 'Chicken breast', portion: '3 oz cooked', protein: 26 },
  { name: 'Tuna, canned', portion: '1 can · 5 oz', protein: 27 },
  { name: 'Salmon', portion: '3 oz cooked', protein: 22 },
  { name: 'Firm tofu', portion: '1/2 cup', protein: 11 },
  { name: 'Lentils', portion: '1/2 cup cooked', protein: 9 },
  { name: 'String cheese', portion: '1 stick', protein: 7 },
  { name: 'Turkey slices', portion: '2 oz', protein: 10 },
  { name: 'Edamame', portion: '1/2 cup', protein: 9 },
];

export const QUICK_FOODS = FOODS.filter((f) =>
  ['Greek yogurt, plain', 'Eggs', 'Protein shake', 'Chicken breast'].includes(f.name),
).map((f) => ({ ...f, short: f.name === 'Greek yogurt, plain' ? 'Greek yogurt' : f.name === 'Eggs' ? '2 eggs' : f.name }));

export const SYMPTOMS: { id: SymptomId; label: string }[] = [
  { id: 'nausea', label: 'Nausea' },
  { id: 'constipation', label: 'Constipation' },
  { id: 'heartburn', label: 'Heartburn' },
  { id: 'fatigue', label: 'Tired' },
  { id: 'no-appetite', label: 'No appetite' },
  { id: 'good', label: 'Feeling good' },
];

export const symptomLabel = (id: SymptomId) => SYMPTOMS.find((s) => s.id === id)?.label ?? id;

export const TRIGGERS = ['Fatty food', 'Ate late', 'Big portion', 'Ate too soon after tablet', 'Alcohol', 'Not sure'];

export const SEVERITY_WORDS = ['', 'Barely there', 'Mild', 'Moderate', 'Strong', 'Severe'];

export const NOISE_WORDS = ['', 'Quiet', 'Low', 'Some', 'Loud', 'Constant'];

/** Show the refill heads-up at or below this many tablets. */
export const REFILL_AT = 7;
