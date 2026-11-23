"use client";

import * as React from "react";
import {
  type Locale,
  defaultLocale,
  detectLocale,
  getContent,
  localisedContent,
} from "@/lib/i18n";
import { usePathname } from "next/navigation";
import { useClientValue } from "@/lib/use-client-value";
import { localeForPath } from "@/lib/nav";

type LocaleContextType = {
  locale: Locale;
  content: (typeof localisedContent)[Locale];
  setLocale: (locale: Locale) => void;
};

const LocaleContext = React.createContext<LocaleContextType | undefined>(
  undefined
);

export function LocaleProvider({ children }: { children: React.ReactNode }) {
  // The browser's locale after hydration (the default before, so server and client match); a
  // manual pick through setLocale wins over it. Under /zh-Hans the route decides, on the server
  // too, so those pages render Chinese without JS.
  const detected = useClientValue(detectLocale, defaultLocale);
  const [picked, setLocale] = React.useState<Locale | null>(null);
  const locale = localeForPath(usePathname()) ?? picked ?? detected;

  const content = React.useMemo(() => getContent(locale), [locale]);

  return (
    <LocaleContext.Provider value={{ locale, content, setLocale }}>
      {children}
    </LocaleContext.Provider>
  );
}

export function useLocale() {
  const context = React.useContext(LocaleContext);
  if (context === undefined) {
    throw new Error("useLocale must be used within a LocaleProvider");
  }
  return context;
}

/** A name as the current language shows it (the data arrays stay English). */
export function useDisplayName() {
  const names: Readonly<Record<string, string>> = useLocale().content.names;
  // Stable per language, so a list built from it can be memoised (MacOSDock resets on a new list).
  return React.useCallback((name: string) => names[name] ?? name, [names]);
}
