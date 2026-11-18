import { ScrollView } from 'react-native';
import { Chip } from '@/components/ui';
import { STARTUP_SORTS, type StartupSort } from '@/models/types';

/** The website's seven sort options. */
export function SortPicker({ value, onChange }: { value: StartupSort; onChange: (s: StartupSort) => void }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, paddingHorizontal: 16 }} accessibilityLabel="Sort by">
      {STARTUP_SORTS.map((s) => (
        <Chip key={s.key} label={s.label} selected={value === s.key} onPress={() => onChange(s.key)} />
      ))}
    </ScrollView>
  );
}
