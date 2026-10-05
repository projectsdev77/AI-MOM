// How to read Firebase Cloud Messaging's answer to a send. Pure, so it can
// be exercised without calling Firebase.

export type PushOutcome = 'sent' | 'dead_token' | 'failed';

/**
 * 'dead_token' means this token will never work again (the app was
 * uninstalled, or the device deleted it when its user signed out), so it
 * should be removed from the profile rather than tried every hour.
 *
 * Deliberately narrow: only FCM's explicit UNREGISTERED error counts. A
 * bare 404 is NOT enough, because the same status comes back for a wrong
 * project id or other misconfiguration, and treating that as "dead token"
 * would wipe every user's token in one run. Anything else (bad credentials,
 * rate limits, outages, a malformed message) is a plain 'failed': keep the
 * token and try again next time.
 */
export function pushOutcome(status: number, body: string): PushOutcome {
  if (status >= 200 && status < 300) return 'sent';
  if (/\bUNREGISTERED\b/.test(body)) return 'dead_token';
  return 'failed';
}
