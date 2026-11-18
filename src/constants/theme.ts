import { Platform } from 'react-native';

export const APP_NAME = 'Dawnwell';

export const C = {
  bg: '#F4F5F1',
  card: '#FFFFFF',
  ink: '#16201B',
  inkSoft: '#3E4842',
  muted: '#56615A',
  line: '#E3E7E1',
  lineSoft: '#EEF0EB',
  field: '#FAFBF8',
  fieldBorder: '#DCE2DA',
  accent: '#0F6B5C',
  accentDark: '#0B4A40',
  accentSoft: '#E6F1EE',
  warm: '#E07B39',
  warmDark: '#B85A1E',
  warmInk: '#8A3E10',
  warmSoft: '#FCE9DC',
  warmLight: '#F2C29E',
  sand: '#F4EFE2',
  sandInk: '#5E4A12',
  neutralSoft: '#F1F2EE',
  white: '#FFFFFF',
} as const;

export const R = { sm: 12, md: 16, lg: 22, xl: 28, pill: 999 } as const;

export const S = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24 } as const;

export const font = Platform.select({ ios: 'System', default: undefined });
