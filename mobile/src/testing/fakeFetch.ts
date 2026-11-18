import { setFetcher } from '@/api/http';

type Reply = { status?: number; body: unknown; headers?: Record<string, string> } | Error;

/** Routes requests to canned replies by URL substring; records every URL requested. */
export function fakeFetch(routes: [string | RegExp, Reply | ((url: string) => Reply)][]) {
  const calls: string[] = [];
  setFetcher((async (input: RequestInfo | URL) => {
    const url = String(input);
    calls.push(url);
    const match = routes.find(([m]) => (typeof m === 'string' ? url.includes(m) : m.test(url)));
    if (!match) throw new TypeError(`Network request failed: ${url}`);
    const reply = typeof match[1] === 'function' ? match[1](url) : match[1];
    if (reply instanceof Error) throw reply;
    return new Response(JSON.stringify(reply.body), { status: reply.status ?? 200, headers: { 'content-type': 'application/json', ...reply.headers } });
  }) as typeof fetch);
  return calls;
}
