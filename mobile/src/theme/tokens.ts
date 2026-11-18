/** From the official logo: brand purple for fills, orange for the wordmark's "Hub". */
export const brand = {
  purple: '#4F3DAD',
  purpleDeep: '#2B2066',
  orange: '#EA5F17',
} as const;

export type Palette = {
  dark: boolean;
  background: string;
  surface: string;
  card: string;
  text: string;
  muted: string;
  subtle: string;
  border: string;
  accent: string;
  onAccent: string;
  /** Purple for text and icons; lighter in dark mode for AA contrast. */
  accentText: string;
  accentSoft: string;
  /** Orange: large text and decoration only. */
  highlight: string;
  skeleton: string;
  verified: string;
  danger: string;
  scrim: string;
};

export const light: Palette = {
  dark: false,
  background: '#F8F6F7',
  surface: '#FFFFFF',
  card: '#FFFFFF',
  text: '#16141A',
  muted: '#5C5966',
  subtle: '#8A8794',
  border: '#E6E3EA',
  accent: '#4F3DAD',
  onAccent: '#FFFFFF',
  accentText: '#4F3DAD',
  accentSoft: '#ECE8FA',
  highlight: '#EA5F17',
  skeleton: '#ECE9EF',
  verified: '#1F6FD1',
  danger: '#B3261E',
  scrim: 'rgba(0,0,0,0.9)',
};

export const dark: Palette = {
  dark: true,
  background: '#0B0B0D',
  surface: '#131316',
  card: '#17171B',
  text: '#F2F1F5',
  muted: '#A8A6B3',
  subtle: '#7D7A88',
  border: '#2A2A31',
  accent: '#8B7BE8',
  onAccent: '#0B0B0D',
  accentText: '#B3A6FF',
  accentSoft: '#241E44',
  highlight: '#FF7A3D',
  skeleton: '#1F1F24',
  verified: '#5EA2F0',
  danger: '#F2B8B5',
  scrim: 'rgba(0,0,0,0.95)',
};

export const fonts = {
  display: 'PlayfairDisplay_700Bold',
  displayHeavy: 'PlayfairDisplay_800ExtraBold',
  body: 'Inter_400Regular',
  medium: 'Inter_500Medium',
  semibold: 'Inter_600SemiBold',
  bold: 'Inter_700Bold',
} as const;

export const radius = { sm: 8, md: 12, lg: 16, xl: 20, pill: 999 } as const;
export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24 } as const;
