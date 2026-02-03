"use client";

import * as React from "react";
import {
  type Locale,
  defaultLocale,
  detectLocale,
  getContent,
  localisedContent,
} from "@/lib/i18n";

type LocaleContextType = {
  locale: Locale;
  content: (typeof localisedContent)[Locale];
  setLocale: (locale: Locale) => void;
};

const LocaleContext = React.createContext<LocaleContextType | undefined>(
  undefined
);

export function LocaleProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocale] = React.useState<Locale>(defaultLocale);
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
    // Detect locale from browser on mount
    const detected = detectLocale();
    setLocale(detected);
  }, []);

  const content = React.useMemo(() => getContent(locale), [locale]);

  // During SSR, use default locale
  if (!mounted) {
    return (
      <LocaleContext.Provider
        value={{
          locale: defaultLocale,
          content: getContent(defaultLocale),
          setLocale,
        }}
      >
        {children}
      </LocaleContext.Provider>
    );
  }

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
