import { Stack, router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Image, KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
import { Field } from '@/components/Field';
import { AppText, Button, Chip, IconButton } from '@/components/ui';
import { env } from '@/config/env';
import { community } from '@/features/community/api';
import { communityMessage } from '@/features/community/errors';
import { finishScreen } from '@/features/community/gate';
import { openLink } from '@/lib/links';
import { showMessage } from '@/lib/toast';
import { usePalette } from '@/theme';

/** Sign in or create an account. Closing it keeps the person browsing as a guest. */
export default function SignInScreen() {
  const p = usePalette();
  const { reason } = useLocalSearchParams<{ reason?: string }>();
  const { auth } = community();
  const [register, setRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});
  const done = useRef(false);

  // Leaving without signing in tells whoever opened this screen.
  useEffect(() => () => finishScreen('signIn', done.current), []);

  async function run(action: () => Promise<boolean>) {
    setBusy(true);
    setError(null);
    try {
      if (await action()) {
        done.current = true;
        finishScreen('signIn', true);
        router.back();
      }
    } catch (e) {
      setError(communityMessage(e));
    } finally {
      setBusy(false);
    }
  }

  function validate() {
    const errors: typeof fieldErrors = {};
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) errors.email = 'Enter a valid email address';
    if (!password) errors.password = 'Enter your password';
    else if (register && password.length < 8) errors.password = 'Use at least 8 characters';
    setFieldErrors(errors);
    return !errors.email && !errors.password;
  }

  const submit = () => {
    if (!validate()) return;
    void run(async () => {
      if (register) {
        await auth.registerWithEmail(email, password);
        showMessage('Account created. Check your email to verify it.');
      } else {
        await auth.signInWithEmail(email, password);
      }
      return true;
    });
  };

  const forgot = () => {
    const e = email.trim();
    if (!e.includes('@')) {
      setError('Enter your email address above first.');
      return;
    }
    void run(async () => {
      await auth.sendPasswordReset(e);
      showMessage(`If ${e} has an account, a reset link is on its way.`);
      return false;
    });
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: p.background }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Stack.Screen
        options={{
          title: '',
          headerLeft: () => <IconButton icon="close" label="Continue as guest" onPress={() => router.back()} />,
        }}
      />
      <ScrollView contentContainerStyle={{ padding: 24, gap: 16 }} keyboardShouldPersistTaps="handled">
        <View style={{ alignItems: 'center', gap: 8 }}>
          <Image source={require('../../../assets/images/logo-mark.png')} style={{ width: 56, height: 56 }} accessibilityIgnoresInvertColors />
          <AppText variant="headline" style={{ textAlign: 'center' }}>
            {register ? 'Join AllBioHub' : 'Welcome back'}
          </AppText>
          <AppText color="muted" style={{ textAlign: 'center' }}>
            {reason || 'Follow startups and topics, join conversations and sync what you save.'}
          </AppText>
        </View>
        <View style={{ flexDirection: 'row', gap: 8, justifyContent: 'center' }}>
          <Chip label="Sign in" selected={!register} onPress={busy ? undefined : () => (setRegister(false), setError(null))} />
          <Chip label="Create account" selected={register} onPress={busy ? undefined : () => (setRegister(true), setError(null))} />
        </View>
        <Field
          label="Email"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
          autoComplete="email"
          textContentType="emailAddress"
          returnKeyType="next"
          error={fieldErrors.email}
        />
        <Field
          label="Password"
          value={password}
          onChangeText={setPassword}
          secureTextEntry={!showPassword}
          autoCapitalize="none"
          autoComplete={register ? 'new-password' : 'current-password'}
          textContentType={register ? 'newPassword' : 'password'}
          onSubmitEditing={submit}
          helper={register ? 'At least 8 characters' : null}
          error={fieldErrors.password}
          trailing={
            <IconButton
              icon={showPassword ? 'eye-off-outline' : 'eye-outline'}
              label={showPassword ? 'Hide password' : 'Show password'}
              size={20}
              color={p.muted}
              onPress={() => setShowPassword(!showPassword)}
            />
          }
        />
        {error ? (
          <AppText color={p.danger} accessibilityLiveRegion="polite">
            {error}
          </AppText>
        ) : null}
        <Button label={register ? 'Create account' : 'Sign in'} onPress={submit} loading={busy} />
        {!register ? <Button kind="text" label="Forgot password?" onPress={forgot} disabled={busy} /> : null}
        {auth.supportsGoogle ? (
          <>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <View style={{ flex: 1, height: 1, backgroundColor: p.border }} />
              <AppText variant="caption" color="subtle">
                or
              </AppText>
              <View style={{ flex: 1, height: 1, backgroundColor: p.border }} />
            </View>
            <Button
              kind="outlined"
              icon="logo-google"
              label="Continue with Google"
              disabled={busy}
              onPress={() => void run(async () => (await auth.signInWithGoogle()) !== null)}
            />
          </>
        ) : null}
        <AppText variant="bodySmall" color="muted" style={{ textAlign: 'center', marginTop: 8 }}>
          You can keep reading without an account. Your email is never shown on your profile.
        </AppText>
        <View style={{ flexDirection: 'row', justifyContent: 'center' }}>
          {env.termsUrl ? <Button kind="text" label="Terms" onPress={() => openLink(env.termsUrl)} /> : null}
          {env.privacyPolicyUrl ? <Button kind="text" label="Privacy policy" onPress={() => openLink(env.privacyPolicyUrl)} /> : null}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
