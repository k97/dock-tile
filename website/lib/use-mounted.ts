import { useSyncExternalStore } from "react";

const emptySubscribe = () => () => {};

/**
 * True only after hydration. The server snapshot and first client render agree
 * (false), then the snapshot flips to true — the mounted-guard for theme-aware
 * rendering without an effect-driven setState (react-hooks/set-state-in-effect).
 */
export function useMounted(): boolean {
  return useSyncExternalStore(
    emptySubscribe,
    () => true,
    () => false,
  );
}
