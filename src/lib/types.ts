export type MedicationId = 'oral-semaglutide' | 'orforglipron' | 'other';

export type Reminders = {
  tablet: boolean;
  waitOver: boolean;
  protein: boolean;
  refill: boolean;
};

export type Settings = {
  onboarded: boolean;
  medication: MedicationId;
  doseLabel: string;
  doseHour: number;
  doseMinute: number;
  waitMinutes: number;
  proteinTarget: number;
  fiberTarget: number;
  waterTarget: number;
  startWeight: number | null;
  goalWeight: number | null;
  tabletsLeft: number | null;
  reminders: Reminders;
};

export type FoodEntry = { id: string; name: string; protein: number; meal: Meal; at: number };

export type Meal = 'Breakfast' | 'Lunch' | 'Dinner' | 'Snack';

export type SymptomId = 'nausea' | 'constipation' | 'heartburn' | 'fatigue' | 'no-appetite' | 'good';

export type SymptomEntry = {
  id: SymptomId;
  severity: number;
  triggers: string[];
  note: string;
  at: number;
};

export type DayLog = {
  takenAt: number | null;
  skipped: boolean;
  water: number;
  fiber: number;
  foodNoise: number | null;
  foods: FoodEntry[];
  symptoms: SymptomEntry[];
  strength: number;
};

export type WeightEntry = { date: string; value: number };

export type DoseChange = { label: string; from: string };

export type AppData = {
  version: number;
  settings: Settings;
  days: Record<string, DayLog>;
  weights: WeightEntry[];
  doseHistory: DoseChange[];
  questions: string;
};
