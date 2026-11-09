"use client";

import { LegalShell, LegalHeading } from "@/components/legal-shell";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";

const link =
  "font-medium text-emerald-600 underline decoration-emerald-600/40 underline-offset-4 transition-colors hover:text-emerald-500 hover:decoration-emerald-500 dark:text-emerald-400 dark:decoration-emerald-400/40 dark:hover:text-emerald-300 dark:hover:decoration-emerald-300";
const body = "leading-relaxed text-muted-foreground";
const list = "flex list-disc flex-col gap-2 pl-6 leading-relaxed text-muted-foreground";
const term = "font-semibold text-foreground";
const path = "rounded bg-muted px-1.5 py-0.5 text-sm text-foreground";

// Every statement here was checked against the app source (DockTile/) on
// 2026-11-09. Re-check after a release that touches analytics, Smart Add,
// diagnostics, permissions or updates.
export function PrivacyContent() {
  const { content } = useLocale();

  return (
    <LegalShell
      eyebrow="Privacy"
      title="Privacy Policy"
      subtitle="The short version: your data stays yours."
      lastUpdated="Last updated: November 2026"
    >
      <p className={body}>
        {siteConfig.appName} is designed with your privacy in mind. This page covers the Mac app
        and this website. Here&apos;s what you need to know:
      </p>

      <LegalHeading>What stays on your Mac</LegalHeading>
      <p className={body}>
        Your tiles, settings and app lists live on your Mac, in these places:
      </p>
      <ul className={list}>
        <li>
          <strong className={term}>Configuration file</strong>:{" "}
          <code className={path}>~/Library/Preferences/com.docktile.configs.json</code> -{" "}
          {content.legal.privacyConfigStores}
        </li>
        <li>
          <strong className={term}>Smart Add history</strong>:{" "}
          <code className={path}>~/Library/Preferences/com.docktile.smartadd.json</code> - which
          apps you open and when (app identifiers and times, the last 60 days), so the + button can
          suggest tiles from the apps you use. Suggestions also read the use counts Spotlight
          already keeps for your apps. This history is kept while {siteConfig.appName} runs, even
          with suggestions switched off in Settings → General.
        </li>
        <li>
          <strong className={term}>Tile apps and a diagnostics log</strong>:{" "}
          <code className={path}>~/Library/Application Support/DockTile/</code> - the tile apps that
          appear in your Dock, and a log of recent activity (it names your tiles and their apps;
          trimmed to the last hour each time the app starts), used to troubleshoot problems.
        </li>
      </ul>
      <p className={body}>
        None of this is sent anywhere. Smart Add history stays on your Mac even when the
        analytics below are on. The diagnostics log leaves your Mac only if you copy it yourself
        (File → Copy Diagnostics) and send it to us.
      </p>

      <LegalHeading>Permissions</LegalHeading>
      <p className={body}>{siteConfig.appName} uses the following system access:</p>
      <ul className={list}>
        <li>
          <strong className={term}>Dock preferences</strong> - to add, remove and reorder tiles.
          Applying a change restarts the Dock; the app asks you the first time.
        </li>
        <li>
          <strong className={term}>Application Support folder</strong> - to store the tile apps.
        </li>
        <li>
          <strong className={term}>Login items</strong> - to start your tiles when you log in so
          they respond instantly. On by default; switch it off in Settings → General.
        </li>
        <li>
          <strong className={term}>Accessibility (optional)</strong> - asked for only when you turn
          on Dock Lock. It lets {siteConfig.appName} keep the pointer away from the Dock&apos;s
          edge on your other displays, so the Dock stays on the one you chose. Pointer movement is
          not recorded.
        </li>
      </ul>

      <LegalHeading>Analytics and crash reports</LegalHeading>
      <p className={body}>
        {siteConfig.appName} includes optional, anonymous usage analytics and crash reporting. As
        a small studio, this is what helps us improve the software: it shows us which features
        matter and catches crashes we&apos;d otherwise never hear about.
      </p>
      <p className={body}>To be upfront about what that means:</p>
      <ul className={list}>
        <li>
          Usage analytics record which features are used (for example, a tile being added, how
          many apps it has, or which layout it uses) along with a random install identifier, your
          Mac model, macOS version, app version and approximate region.
        </li>
        <li>
          Crash reports contain technical details of the error. Occasionally an error includes a
          file path on your Mac, which can contain your account name.
        </li>
        <li>
          They never include your tile names, your app lists, or the contents of your files.
        </li>
        <li>
          This data is{" "}
          <strong className={term}>never shared with, or sold to, advertisers or third parties</strong>
          , and is used only to improve the software and keep it stable.
        </li>
        <li>
          You can switch it off at any time with the{" "}
          <strong className={term}>&quot;Share anonymous usage data&quot;</strong> toggle in
          Settings → General.
        </li>
      </ul>

      <LegalHeading>Updates</LegalHeading>
      <p className={body}>
        Once a day, {siteConfig.appName} checks this website for a new version and installs it
        automatically in the background. The check is a standard web request (your IP address
        and the app&apos;s version); no other information about your Mac is sent. Downloads come
        from GitHub, which may keep standard server logs as described in{" "}
        <a
          href="https://docs.github.com/en/site-policy/privacy-policies"
          target="_blank"
          rel="noopener noreferrer"
          className={link}
        >
          GitHub&apos;s Privacy Policy
        </a>
        .
      </p>

      <LegalHeading>This website</LegalHeading>
      <p className={body}>
        This website uses Google Analytics to count visits and downloads: the pages you view, the
        site that sent you, your browser and device type, and your approximate location. It sets
        analytics cookies to do this. You can block them with your browser&apos;s settings or
        Google&apos;s{" "}
        <a
          href="https://tools.google.com/dlpage/gaoptout"
          target="_blank"
          rel="noopener noreferrer"
          className={link}
        >
          opt-out add-on
        </a>
        . The site is hosted on Vercel, which keeps standard server logs.
      </p>

      <LegalHeading>Feedback and support</LegalHeading>
      <p className={body}>
        If you email us, we use your message and address only to reply. Feature requests and bug
        reports filed on GitHub are public, so please email diagnostics to us rather than pasting
        them into an issue.
      </p>

      <LegalHeading>Third-party services</LegalHeading>
      <ul className={list}>
        <li>
          <strong className={term}>Google Firebase</strong> (Analytics and Crashlytics) - the
          app&apos;s optional analytics and crash reports.
        </li>
        <li>
          <strong className={term}>Google Analytics</strong> - this website&apos;s visit counts.
        </li>
        <li>
          <strong className={term}>GitHub</strong> - app downloads, the source code, and public
          issues.
        </li>
        <li>
          <strong className={term}>Vercel</strong> - hosts this website and the update check.
        </li>
      </ul>
      <p className={body}>There are no advertising SDKs, and we never sell data.</p>

      <LegalHeading>Contact</LegalHeading>
      <p className={body}>
        If you have questions about this privacy policy, please{" "}
        <a href={`mailto:${siteConfig.contactEmail}`} className={link}>
          get in touch
        </a>
        .
      </p>
    </LegalShell>
  );
}
