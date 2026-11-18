import type { ReactNode } from 'react';
import { View } from 'react-native';
import { AppText } from '@/components/ui';
import { compactNumber } from '@/lib/text';

export function FeedHeader({
  overline,
  title,
  description,
  count,
  action,
}: {
  overline: string;
  title: string;
  description?: string;
  count?: number;
  /** E.g. the Follow button on a category. */
  action?: ReactNode;
}) {
  return (
    <View style={{ paddingHorizontal: 16, paddingTop: 8, paddingBottom: 12, gap: 6 }}>
      <AppText variant="overline" color="accent">
        {overline}
      </AppText>
      <AppText variant="display" accessibilityRole="header">
        {title}
      </AppText>
      {description ? <AppText color="muted">{description}</AppText> : null}
      {count ? (
        <AppText variant="caption" color="subtle">
          {compactNumber(count)} {count === 1 ? 'story' : 'stories'}
        </AppText>
      ) : null}
      {action ? <View style={{ flexDirection: 'row', marginTop: 4 }}>{action}</View> : null}
    </View>
  );
}
