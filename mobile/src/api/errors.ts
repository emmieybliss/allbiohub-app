export type AppErrorKind = 'offline' | 'timeout' | 'notFound' | 'server' | 'badResponse' | 'cancelled' | 'unknown';

/** Every failure the data layer raises. Screens turn [kind] into a message. */
export class AppError extends Error {
  constructor(
    readonly kind: AppErrorKind,
    readonly status?: number,
    detail?: string,
  ) {
    super(detail ?? kind);
    this.name = 'AppError';
  }

  static from(error: unknown): AppError {
    if (error instanceof AppError) return error;
    if (error instanceof Error && error.name === 'AbortError') return new AppError('cancelled');
    if (error instanceof TypeError) return new AppError('offline', undefined, error.message);
    return new AppError('unknown', undefined, String(error));
  }
}

/** The startup directory add-on isn't switched on (its routes answer 404). */
export class StartupDirectoryUnavailable extends Error {
  constructor() {
    super('Startup directory API is not available');
    this.name = 'StartupDirectoryUnavailable';
  }
}

export function errorMessage(error: unknown): { title: string; body: string } {
  const kind = error instanceof AppError ? error.kind : 'unknown';
  switch (kind) {
    case 'offline':
      return { title: "You're offline", body: 'Check your connection and try again.' };
    case 'timeout':
      return { title: 'This is taking too long', body: 'AllBioHub is slow to answer. Try again in a moment.' };
    case 'notFound':
      return { title: 'Not found', body: "This page doesn't exist any more, or the link is wrong." };
    case 'server':
      return { title: 'AllBioHub is having trouble', body: 'The website returned an error. Try again in a moment.' };
    default:
      return { title: 'Something went wrong', body: 'Try again in a moment.' };
  }
}
