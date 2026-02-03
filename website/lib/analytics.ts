// Google Analytics utility functions
// GA Measurement ID: G-PP04F8Z0EP

declare global {
  interface Window {
    gtag: (
      command: "config" | "event" | "js",
      targetId: string,
      config?: Record<string, unknown>
    ) => void;
    dataLayer: unknown[];
  }
}

export const GA_MEASUREMENT_ID = "G-PP04F8Z0EP";

// Track page views (called automatically by gtag config)
export function pageview(url: string) {
  if (typeof window.gtag !== "undefined") {
    window.gtag("config", GA_MEASUREMENT_ID, {
      page_path: url,
    });
  }
}

// Generic event tracking
export function trackEvent(
  action: string,
  category: string,
  label?: string,
  value?: number
) {
  if (typeof window.gtag !== "undefined") {
    window.gtag("event", action, {
      event_category: category,
      event_label: label,
      value: value,
    });
  }
}

// Specific event tracking functions

export function trackDownloadClick() {
  trackEvent("download_click", "engagement", "download_button");
}

export function trackReleaseNotesClick() {
  trackEvent("release_notes_click", "engagement", "release_notes_link");
}

export function trackFaqOpen(question: string) {
  trackEvent("faq_open", "engagement", question);
}

export function trackExternalLinkClick(url: string, location: string) {
  trackEvent("external_link_click", "outbound", `${location}: ${url}`);
}

export function trackThemeChange(theme: string) {
  trackEvent("theme_change", "preferences", theme);
}

export function trackContactClick() {
  trackEvent("contact_click", "engagement", "support_email");
}
