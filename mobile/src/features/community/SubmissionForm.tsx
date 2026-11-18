import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import { type ReactNode, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
import { useQueryClient } from '@tanstack/react-query';
import { Field } from '@/components/Field';
import { AppText, Button, IconButton } from '@/components/ui';
import { usePalette } from '@/theme';
import { community } from './api';
import { requireAccount, showCommunityError } from './gate';
import { SUBMISSION_RECEIVED } from './models';
import { pickImage } from './pickImage';

export type FieldSpec = {
  label: string;
  hint?: string;
  min?: number;
  max?: number;
  lines?: number;
  kind?: 'text' | 'url' | 'email' | 'phone' | 'number' | 'year';
};

function looksLikeUrl(v: string) {
  try {
    return new URL(v.includes('://') ? v : `https://${v}`).hostname.includes('.');
  } catch {
    return false;
  }
}

/** The same checks the Flutter forms made; the server checks again. */
export function validateField(spec: FieldSpec, raw: string): string | null {
  const v = raw.trim();
  const min = spec.min ?? 0;
  const max = spec.max ?? 200;
  if (!v) return min > 0 ? `${spec.label} is required.` : null;
  if (v.length < min) return `${spec.label} needs at least ${min} characters.`;
  if (v.length > max) return `${spec.label} must be at most ${max} characters.`;
  if (spec.kind === 'url' && !looksLikeUrl(v)) return 'Enter a web address.';
  if (spec.kind === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return 'Enter a valid email address.';
  if (spec.kind === 'year') {
    const year = Number(v);
    const now = new Date().getFullYear();
    if (!Number.isInteger(year) || year < 1900 || year > now) return `Enter a year between 1900 and ${now}.`;
  }
  return null;
}

/** Form state for a set of named fields, with validation on submit. */
export function useForm<K extends string>(specs: Record<K, FieldSpec>) {
  const [values, setValues] = useState(() => Object.fromEntries(Object.keys(specs).map((k) => [k, ''])) as Record<K, string>);
  const [errors, setErrors] = useState<Partial<Record<K, string>>>({});
  const field = (key: K) => {
    const spec = specs[key];
    return (
      <Field
        key={key}
        label={spec.label}
        required={(spec.min ?? 0) > 0}
        placeholder={spec.hint}
        value={values[key]}
        onChangeText={(t) => setValues((v) => ({ ...v, [key]: t }))}
        multiline={(spec.lines ?? 1) > 1}
        maxLength={(spec.max ?? 200) > 200 ? spec.max : undefined}
        keyboardType={
          spec.kind === 'url' ? 'url' : spec.kind === 'email' ? 'email-address' : spec.kind === 'phone' ? 'phone-pad' : spec.kind === 'year' ? 'number-pad' : 'default'
        }
        autoCapitalize={spec.kind === 'url' || spec.kind === 'email' ? 'none' : 'sentences'}
        error={errors[key]}
      />
    );
  };
  const validate = () => {
    const next: Partial<Record<K, string>> = {};
    for (const key of Object.keys(specs) as K[]) {
      const e = validateField(specs[key], values[key]);
      if (e) next[key] = e;
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  };
  /** Trimmed value, or null when empty. */
  const opt = (key: K) => values[key].trim() || null;
  const text = (key: K) => values[key].trim();
  return { values, field, validate, opt, text };
}

/** Optional image for a submission (a screenshot or logo). Uploaded when the form is sent. */
export function ImageField({ label, value, onChange }: { label: string; value: { uri: string; type: string } | null; onChange: (v: { uri: string; type: string } | null) => void }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
      {value ? <Image source={{ uri: value.uri }} style={{ width: 56, height: 56, borderRadius: 8 }} accessibilityLabel="Chosen image" /> : null}
      <Button
        kind="outlined"
        icon="image-outline"
        label={value ? 'Change image' : label}
        onPress={async () => {
          const picked = await pickImage(false);
          if (picked) onChange(picked);
        }}
        style={{ flex: 1 }}
      />
      {value ? <IconButton icon="close" label="Remove image" onPress={() => onChange(null)} /> : null}
    </View>
  );
}

export async function uploadImage(image: { uri: string; type: string } | null): Promise<string | null> {
  return image ? community().api.uploadSubmissionImage(image.uri, image.type) : null;
}

/** Shared shell: a scrolling form, a note that editors review everything, and a submit button that signs in first. */
export function SubmissionForm({ intro, children, validate, submit }: { intro: string; children: ReactNode; validate: () => boolean; submit: () => Promise<string> }) {
  const p = usePalette();
  const queryClient = useQueryClient();
  const [busy, setBusy] = useState(false);

  async function send() {
    if (!validate()) return;
    if (!(await requireAccount({ profile: false, verified: true, reason: 'Sign in to send a submission to the AllBioHub editors.' }))) return;
    setBusy(true);
    try {
      const message = await submit();
      void queryClient.invalidateQueries({ queryKey: ['community', 'submissions'] });
      Alert.alert('Thank you', message || SUBMISSION_RECEIVED, [{ text: 'OK', onPress: () => router.back() }], { onDismiss: () => router.back() });
    } catch (e) {
      showCommunityError(e);
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: p.background }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: 16, gap: 14, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <AppText color="muted">{intro}</AppText>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Ionicons name="information-circle-outline" size={18} color={p.subtle} />
          <AppText variant="bodySmall" color="subtle" style={{ flex: 1 }}>
            Editors review every submission before anything appears on AllBioHub. Nothing is published automatically.
          </AppText>
        </View>
        {children}
        <Button label="Submit for review" onPress={send} loading={busy} style={{ marginTop: 8 }} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
