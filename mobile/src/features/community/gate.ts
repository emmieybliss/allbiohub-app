import { router } from 'expo-router';
import { Alert } from 'react-native';
import { showMessage } from '@/lib/toast';
import { community } from './api';
import { CommunityError, communityMessage } from './errors';
import { isRestricted } from './models';
import { featureOn, profileLoaded, useSession } from './store';

type Screen = 'signIn' | 'username';

const waiting = new Map<Screen, (ok: boolean) => void>();

/** Opens the sign-in or username screen and resolves when it closes: true when it finished. */
function openAndWait(screen: Screen, href: string): Promise<boolean> {
  waiting.get(screen)?.(false);
  return new Promise((resolve) => {
    waiting.set(screen, resolve);
    router.push(href as never);
  });
}

/** Called by those screens: with true when done, with false when closed. */
export function finishScreen(screen: Screen, ok: boolean) {
  const resolve = waiting.get(screen);
  waiting.delete(screen);
  resolve?.(ok);
}

export function showCommunityError(error: unknown) {
  showMessage(communityMessage(error));
}

/** Asks the person to verify their email. Resolves true once it shows as verified. */
export function verifyEmail(): Promise<boolean> {
  const { auth } = community();
  const email = useSession.getState().user?.email ?? 'your email';
  return new Promise((resolve) => {
    Alert.alert('Verify your email', `We sent a link to ${email}. Open it, then come back and tap “I’ve verified”.`, [
      {
        text: 'Send again',
        onPress: () => {
          auth.sendEmailVerification().then(() => showMessage('Verification email sent.'), showCommunityError);
          resolve(false);
        },
      },
      {
        text: 'I’ve verified',
        onPress: () => {
          auth.reload().then(
            (user) => {
              if (user?.emailVerified) resolve(true);
              else {
                showMessage('Not verified yet. Check your inbox.');
                resolve(false);
              }
            },
            (e) => {
              showCommunityError(e);
              resolve(false);
            },
          );
        },
      },
    ], { cancelable: true, onDismiss: () => resolve(false) });
  });
}

/**
 * Makes sure the person can take part before a community action: signed in,
 * with a username when [profile], and a verified email when [verified].
 * Guides them through whatever is missing and resolves whether they may go
 * ahead. Reading never needs any of this.
 */
export async function requireAccount({
  profile = true,
  verified = false,
  reason = 'Sign in to take part in the AllBioHub community.',
}: { profile?: boolean; verified?: boolean; reason?: string } = {}): Promise<boolean> {
  if (!featureOn('accounts')) return false;
  let user = useSession.getState().user;
  if (!user) {
    if (!(await openAndWait('signIn', `/account/sign-in?reason=${encodeURIComponent(reason)}`))) return false;
    user = useSession.getState().user;
    if (!user) return false;
  }
  if (profile && !(await profileLoaded())) {
    if (!(await openAndWait('username', '/account/username'))) return false;
  }
  if (verified && !useSession.getState().user?.emailVerified) {
    return verifyEmail();
  }
  if (isRestricted(useSession.getState().account)) {
    showCommunityError(new CommunityError('restricted'));
    return false;
  }
  return true;
}
