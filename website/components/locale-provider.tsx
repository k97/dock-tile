"use client";

import * as React from "react";
import {
  type Locale,
  defaultLocale,
  detectLocale,
  getContent,
  localisedContent,
} from "@/lib/i18n";
import { useClientValue } from "@/lib/use-client-value";

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
  // manual pick through setLocale wins over it.
  const detected = useClientValue(detectLocale, defaultLocale);
  const [picked, setLocale] = React.useState<Locale | null>(null);
  const locale = picked ?? detected;

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
