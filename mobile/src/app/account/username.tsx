import { Ionicons } from '@expo/vector-icons';
import { Stack, router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, ScrollView } from 'react-native';
import { Field } from '@/components/Field';
import { AppText, Button } from '@/components/ui';
import { community } from '@/features/community/api';
import { communityMessage } from '@/features/community/errors';
import { finishScreen } from '@/features/community/gate';
import { nextUsernameChange, normalizeUsername, usernameRule } from '@/features/community/models';
import { useSession } from '@/features/community/store';
import { usePalette } from '@/theme';

const dateFormat = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'long', year: 'numeric' });

/** Picks a unique username: first-time setup, or ?change=1 to change it later. */
export default function UsernameScreen() {
  const p = usePalette();
  const changing = useLocalSearchParams<{ change?: string }>().change === '1';
  const { api } = community();
  const [initial] = useState(() => useSession.getState());
  const [username, setUsername] = useState(initial.profile?.username ?? '');
  const [name, setName] = useState(initial.profile?.displayName ?? initial.user?.displayName ?? '');
  const [checked, setChecked] = useState<{ username: string; ok: boolean; message?: string } | null>(null);
  // Only the answer for what is in the box now counts.
  const availability = checked?.username === username ? checked : null;
  const [checking, setChecking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const done = useRef(false);
  const account = useSession((s) => s.account);
  const next = nextUsernameChange(account);
  const locked = changing && !!next && next > new Date();
  const rule = username ? usernameRule(username) : null;

  useEffect(() => () => finishScreen('username', done.current), []);

  // Checks availability half a second after typing stops.
  useEffect(() => {
    if (!username || usernameRule(username)) return;
    let alive = true;
    const timer = setTimeout(async () => {
      setChecking(true);
      try {
        const r = await api.checkUsername(username);
        if (alive) setChecked({ username, ok: r.available, message: r.available ? 'Available' : r.message });
      } catch (e) {
        if (alive) setChecked({ username, ok: false, message: communityMessage(e) });
      } finally {
        if (alive) setChecking(false);
      }
    }, 500);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [username, api]);

  async function save() {
    const ruleError = usernameRule(username);
    const missingName = !changing && !name.trim();
    setNameError(missingName ? 'Enter your name' : null);
    if (ruleError || missingName) {
      setError(ruleError);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (changing) await api.changeUsername(normalizeUsername(username));
      else await api.createProfile(normalizeUsername(username), name.trim());
      done.current = true;
      finishScreen('username', true);
      router.back();
    } catch (e) {
      setError(communityMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView style={{ backgroundColor: p.background }} contentContainerStyle={{ padding: 24, gap: 16 }} keyboardShouldPersistTaps="handled">
      <Stack.Screen options={{ title: changing ? 'Change username' : 'Choose a username' }} />
      <AppText color="muted">
        {changing ? 'Your old username becomes available to others.' : 'This is how you appear when you comment. You can change it later.'}
      </AppText>
      <Field
        label="Username"
        prefix="@"
        value={username}
        onChangeText={setUsername}
        editable={!locked}
        autoCapitalize="none"
        autoCorrect={false}
        helper={availability?.message ?? '3–20 letters, numbers or underscores'}
        error={rule ?? (availability && !availability.ok ? availability.message : null)}
        trailing={
          checking ? (
            <ActivityIndicator size="small" color={p.accentText} />
          ) : availability ? (
            <Ionicons name={availability.ok ? 'checkmark-circle' : 'alert-circle-outline'} size={20} color={availability.ok ? p.verified : p.danger} />
          ) : null
        }
      />
      {locked && next ? (
        <AppText variant="bodySmall" color="muted">
          {`You can change your username again on ${dateFormat.format(next)}.`}
        </AppText>
      ) : null}
      {!changing ? (
        <Field label="Display name" value={name} onChangeText={setName} maxLength={50} autoCapitalize="words" error={nameError} />
      ) : null}
      {error && !rule ? <AppText color={p.danger}>{error}</AppText> : null}
      <Button label={changing ? 'Save username' : 'Continue'} onPress={save} loading={busy} disabled={locked} />
    </ScrollView>
  );
}
