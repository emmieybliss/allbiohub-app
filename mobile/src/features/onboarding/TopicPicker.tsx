import { View } from 'react-native';
import { useCategories } from '@/api/queries';
import { Chip, ErrorView, SkeletonBox } from '@/components/ui';

/** Pick editorial categories (real ones from the website). */
export function TopicPicker({ selected, onChange }: { selected: string[]; onChange: (slugs: string[]) => void }) {
  const q = useCategories();
  if (q.isError) return <ErrorView error={q.error} onRetry={() => q.refetch()} />;
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
      {q.data
        ? q.data.map((c) => (
            <Chip
              key={c.id}
              label={c.name}
              selected={selected.includes(c.slug)}
              onPress={() => onChange(selected.includes(c.slug) ? selected.filter((s) => s !== c.slug) : [...selected, c.slug])}
            />
          ))
        : [0, 1, 2, 3, 4, 5].map((i) => <SkeletonBox key={i} height={36} width={110} radius={18} />)}
    </View>
  );
}
