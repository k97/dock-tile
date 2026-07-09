import type { Metadata } from "next";
import Script from "next/script";
import { Inter, Special_Gothic_Expanded_One } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";
import { LocaleProvider } from "@/components/locale-provider";
import { Header } from "@/components/header";
import { JsonLd } from "@/components/json-ld";
import { siteConfig } from "@/lib/config";
import { websiteSchema } from "@/lib/schema";
import { GA_MEASUREMENT_ID } from "@/lib/analytics";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const specialGothic = Special_Gothic_Expanded_One({
  variable: "--font-special-gothic",
  weight: "400",
  subsets: ["latin"],
  display: "swap",
  // This font has no metric data in next/font, so the auto-generated
  // metrics-matched fallback fails ("Failed to find font override values").
  // Opt out and supply our own fallback chain (mirrors --font-display).
  adjustFontFallback: false,
  fallback: ["system-ui", "sans-serif"],
});

export const metadata: Metadata = {
  title: `${siteConfig.appName} - ${siteConfig.tagline}`,
  description: siteConfig.description,
  metadataBase: new URL(siteConfig.siteUrl),
  alternates: { canonical: "/" },
  openGraph: {
    title: `${siteConfig.appName} - ${siteConfig.tagline}`,
    description: siteConfig.description,
    url: "/",
    siteName: siteConfig.appName,
    type: "website",
  },
  // Card type only — X/Twitter falls back to each page's og:title/description/
  // image, so subpages don't inherit the homepage's text here.
  twitter: {
    card: "summary_large_image",
  },
  icons: {
    icon: [
      { url: "/favicon/favicon.ico" },
      { url: "/favicon/favicon-96x96.png", sizes: "96x96", type: "image/png" },
      { url: "/favicon/favicon.svg", type: "image/svg+xml" },
    ],
    shortcut: "/favicon/favicon.ico",
    apple: "/favicon/apple-touch-icon.png",
  },
  manifest: "/favicon/site.webmanifest",
  appleWebApp: {
    title: "Dock Tile",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* Pre-paint: after the first load of a session, flag <html> so the
            branded load veil is skipped with NO flash (CSS: [data-veil-shown]
            .hero-veil). The first load sets the session key and lets it play.
            Runs before the veil is parsed, so a repeat load never shows it. */}
        <script
          dangerouslySetInnerHTML={{
            __html:
              "(function(){try{var k='dt-veil-shown';if(sessionStorage.getItem(k)){document.documentElement.setAttribute('data-veil-shown','')}else{sessionStorage.setItem(k,'1')}}catch(e){}})();",
          }}
        />
        {/* No JS → the veil can never lift, so never show it. */}
        <noscript>
          <style>{".hero-veil{display:none!important}"}</style>
        </noscript>
        <Script
          src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', '${GA_MEASUREMENT_ID}');
          `}
        </Script>
      </head>
      <body
        className={`${inter.variable} ${specialGothic.variable} font-sans antialiased `}
      >
        <JsonLd data={websiteSchema} />
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <LocaleProvider>
            <Header />
            {children}
          </LocaleProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
