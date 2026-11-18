import { useColorScheme } from 'react-native';
import { usePreferences } from '@/stores/preferences';
import { dark, light, type Palette } from './tokens';

export function usePalette(): Palette {
  const mode = usePreferences((s) => s.themeMode);
  const system = useColorScheme();
  const isDark = mode === 'dark' || (mode === 'system' && system === 'dark');
  return isDark ? dark : light;
}

export * from './tokens';
