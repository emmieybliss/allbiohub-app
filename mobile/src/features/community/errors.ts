/** Why a community action failed, in words that can be shown to people. */
export type CommunityErrorKind =
  | 'offline'
  | 'signInRequired'
  | 'emailUnverified'
  | 'profileRequired'
  | 'rateLimited'
  | 'restricted'
  | 'forbidden'
  | 'invalid'
  | 'notFound'
  | 'alreadyExists'
  | 'unavailable'
  | 'unknown';

export const OFFLINE_MESSAGE = 'You are offline. Connect to the internet to perform this action.';

const MESSAGES: Record<CommunityErrorKind, string> = {
  offline: OFFLINE_MESSAGE,
  signInRequired: 'Sign in to do this.',
  emailUnverified: 'Verify your email address first. Check your inbox for the link.',
  profileRequired: 'Choose a username first.',
  rateLimited: 'You’re doing that too often. Try again later.',
  restricted: 'Your account can’t take part in the community right now.',
  forbidden: 'You can’t do that.',
  invalid: 'Check what you entered and try again.',
  notFound: 'This is no longer available.',
  alreadyExists: 'That already exists.',
  unavailable: 'Community features aren’t available right now.',
  unknown: 'Something went wrong. Please try again.',
};

export class CommunityError extends Error {
  readonly kind: CommunityErrorKind;
  /** Form field the server objected to, when it said. */
  readonly field?: string;

  constructor(kind: CommunityErrorKind, message?: string | null, field?: string) {
    super(message || MESSAGES[kind]);
    this.name = 'CommunityError';
    this.kind = kind;
    this.field = field;
  }
}

type FirebaseLike = { code?: unknown; message?: unknown; details?: unknown; userInfo?: unknown };

/** "functions/not-found" -> "not-found". */
function codeOf(error: FirebaseLike): string {
  const code = typeof error.code === 'string' ? error.code : '';
  return code.includes('/') ? code.slice(code.indexOf('/') + 1) : code;
}

function productOf(error: FirebaseLike): string {
  const code = typeof error.code === 'string' ? error.code : '';
  return code.includes('/') ? code.slice(0, code.indexOf('/')) : '';
}

/** The server's own message, without the "[functions/xyz]" prefix React Native Firebase adds. */
function serverMessage(error: FirebaseLike): string | undefined {
  const m = typeof error.message === 'string' ? error.message.replace(/^\[[^\]]+\]\s*/, '') : '';
  return m || undefined;
}

const AUTH_ERRORS: Record<string, [CommunityErrorKind, string, string?]> = {
  'network-request-failed': ['offline', OFFLINE_MESSAGE],
  'invalid-credential': ['invalid', 'That email and password don’t match an account.'],
  'wrong-password': ['invalid', 'That email and password don’t match an account.'],
  'user-not-found': ['invalid', 'That email and password don’t match an account.'],
  'invalid-login-credentials': ['invalid', 'That email and password don’t match an account.'],
  'email-already-in-use': ['alreadyExists', 'An account already uses that email. Try signing in.', 'email'],
  'invalid-email': ['invalid', 'Enter a valid email address.', 'email'],
  'weak-password': ['invalid', 'Use a password with at least 8 characters.', 'password'],
  'too-many-requests': ['rateLimited', 'Too many attempts. Wait a few minutes and try again.'],
  'user-disabled': ['restricted', 'This account has been disabled.'],
  'requires-recent-login': ['invalid', 'Sign in again to continue.'],
  'account-exists-with-different-credential': [
    'alreadyExists',
    'This email already has an account with a password. Sign in with your email and password.',
  ],
  'operation-not-allowed': ['unavailable', 'This way of signing in isn’t switched on yet.'],
};

/** Turns a Firebase (functions, auth, Firestore, Storage) error into a CommunityError. */
export function toCommunityError(error: unknown): CommunityError {
  if (error instanceof CommunityError) return error;
  if (!error || typeof error !== 'object') return new CommunityError('unknown');
  const e = error as FirebaseLike;
  const code = codeOf(e);
  const product = productOf(e);

  if (product === 'auth') {
    const known = AUTH_ERRORS[code];
    return known ? new CommunityError(known[0], known[1], known[2]) : new CommunityError('unknown');
  }

  if (product === 'functions') {
    const details = (e.details ?? (e.userInfo as { details?: unknown } | undefined)?.details ?? {}) as Record<string, unknown>;
    const reason = details.reason;
    const field = typeof details.field === 'string' ? details.field : undefined;
    const message = serverMessage(e);
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return new CommunityError('offline');
      case 'unauthenticated':
        return new CommunityError('signInRequired');
      case 'resource-exhausted':
        return new CommunityError('rateLimited', message);
      case 'failed-precondition':
        if (reason === 'email_unverified') return new CommunityError('emailUnverified');
        if (reason === 'profile_missing') return new CommunityError('profileRequired');
        return new CommunityError('invalid', message, field);
      case 'permission-denied':
        if (reason === 'banned' || reason === 'suspended') return new CommunityError('restricted', message);
        return new CommunityError('forbidden', message);
      case 'invalid-argument':
        return new CommunityError('invalid', message, field);
      case 'not-found':
        return new CommunityError('notFound', message);
      case 'already-exists':
        return new CommunityError('alreadyExists', message, field);
      default:
        return String(message).toLowerCase().includes('network') ? new CommunityError('offline') : new CommunityError('unknown');
    }
  }

  // Firestore, Storage and anything else.
  switch (code) {
    case 'unavailable':
      return new CommunityError('offline');
    case 'permission-denied':
    case 'unauthorized':
      return new CommunityError('forbidden');
    case 'not-found':
    case 'object-not-found':
      return new CommunityError('notFound');
    default:
      return new CommunityError('unknown');
  }
}

export function communityMessage(error: unknown): string {
  return toCommunityError(error).message;
}
