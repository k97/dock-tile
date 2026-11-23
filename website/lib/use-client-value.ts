import { useCallback, useSyncExternalStore } from "react";

const noSubscription = () => () => {};

/**
 * A browser-only value, read without setState in an effect: `server` in the server render AND the
 * hydration pass (so they match), the real value right after. `read` must return a primitive or a
 * stable reference. Not subscribed: a later change shows only on the next render, so use
 * `useMediaQuery` for a setting the user can change while the page is open.
 */
export function useClientValue<T>(read: () => T, server: T): T {
  return useSyncExternalStore(noSubscription, read, () => server);
}

/** True once hydrated: replaces the `mounted` flag set in an effect. */
export function useHydrated(): boolean {
  return useClientValue(() => true, false);
}

/** A media query, live (it updates when the setting changes); false on the server. */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const list = window.matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    },
    [query],
  );
  return useSyncExternalStore(subscribe, () => window.matchMedia(query).matches, () => false);
}
