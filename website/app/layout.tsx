import type { Metadata } from "next";
import Script from "next/script";
import { Inter, Special_Gothic_Expanded_One } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";
import { LocaleProvider } from "@/components/locale-provider";
import { Header } from "@/components/header";
import { siteConfig } from "@/lib/config";
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
});

export const metadata: Metadata = {
  title: `${siteConfig.appName} - ${siteConfig.tagline}`,
  description: siteConfig.description,
  metadataBase: new URL(siteConfig.siteUrl),
  openGraph: {
    title: siteConfig.appName,
    description: siteConfig.tagline,
    url: siteConfig.siteUrl,
    siteName: siteConfig.appName,
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: siteConfig.appName,
    description: siteConfig.tagline,
  },
  icons: {
    icon: [
      { url: "/favicon/favicon.ico", sizes: "any" },
      { url: "/favicon/favicon-16x16.png", sizes: "16x16", type: "image/png" },
      { url: "/favicon/favicon-32x32.png", sizes: "32x32", type: "image/png" },
    ],
    apple: [
      { url: "/favicon/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
    ],
    other: [
      { rel: "icon", url: "/favicon/android-chrome-192x192.png", sizes: "192x192", type: "image/png" },
      { rel: "icon", url: "/favicon/android-chrome-512x512.png", sizes: "512x512", type: "image/png" },
    ],
  },
  manifest: "/favicon/site.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
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
