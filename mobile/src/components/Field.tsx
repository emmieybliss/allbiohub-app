import type { ReactNode } from 'react';
import { StyleSheet, TextInput, type TextInputProps, View } from 'react-native';
import { fonts, radius, usePalette } from '@/theme';
import { AppText, MAX_FONT_SCALE } from './ui';

/** A labelled text box with helper text, an error and an optional counter. */
export function Field({
  label,
  required,
  helper,
  error,
  trailing,
  prefix,
  multiline,
  maxLength,
  value,
  style,
  ...props
}: TextInputProps & {
  label: string;
  required?: boolean;
  helper?: string | null;
  error?: string | null;
  trailing?: ReactNode;
  prefix?: string;
}) {
  const p = usePalette();
  const showCounter = !!maxLength && maxLength > 200;
  return (
    <View style={{ gap: 6 }}>
      <AppText variant="label">{required ? `${label} *` : label}</AppText>
      <View style={[styles.box, { borderColor: error ? p.danger : p.border, backgroundColor: p.card }, multiline && { alignItems: 'flex-start' }]}>
        {prefix ? <AppText color="muted">{prefix}</AppText> : null}
        <TextInput
          {...props}
          value={value}
          multiline={multiline}
          maxLength={maxLength}
          accessibilityLabel={label}
          placeholderTextColor={p.subtle}
          maxFontSizeMultiplier={MAX_FONT_SCALE}
          style={[
            styles.input,
            { color: p.text, fontFamily: fonts.body },
            multiline && { minHeight: 96, textAlignVertical: 'top', paddingTop: 12 },
            style,
          ]}
        />
        {trailing}
      </View>
      {error ? (
        <AppText variant="bodySmall" color={p.danger} accessibilityLiveRegion="polite">
          {error}
        </AppText>
      ) : helper || showCounter ? (
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <AppText variant="bodySmall" color="muted" style={{ flex: 1 }}>
            {helper ?? ''}
          </AppText>
          {showCounter ? (
            <AppText variant="caption" color="subtle">
              {`${value?.length ?? 0}/${maxLength}`}
            </AppText>
          ) : null}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  box: { flexDirection: 'row', alignItems: 'center', gap: 4, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 12 },
  input: { flex: 1, fontSize: 15, minHeight: 48, paddingVertical: 10 },
});
