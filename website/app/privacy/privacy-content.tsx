"use client";

import { LegalShell, LegalHeading } from "@/components/legal-shell";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";

export function PrivacyContent() {
  const { content } = useLocale();

  return (
    <LegalShell
      eyebrow="Privacy"
      title="Privacy Policy"
      subtitle="The short version: your data stays yours."
      lastUpdated="Last updated: July 2026"
    >
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} is designed with your privacy in mind.
        Here&apos;s what you need to know:
      </p>

      <LegalHeading>Data Collection</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        <strong className="font-semibold text-foreground">
          {siteConfig.appName} does not collect any personal data.
        </strong>{" "}
        Your tiles, settings, and app lists live entirely on your Mac.
        The only thing the app ever sends anywhere is the optional,
        anonymous usage data described under Analytics below.
      </p>

      <LegalHeading>Local Storage</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} stores the following data locally on your
        Mac:
      </p>
      <ul className="flex list-disc flex-col gap-2 pl-6 leading-relaxed text-muted-foreground">
        <li>
          <strong className="font-semibold text-foreground">Configuration file</strong>:{" "}
          <code className="rounded bg-muted px-1.5 py-0.5 text-sm text-foreground">
            ~/Library/Preferences/com.docktile.configs.json
          </code>{" "}
          - {content.legal.privacyConfigStores}
        </li>
        <li>
          <strong className="font-semibold text-foreground">Helper bundles</strong>:{" "}
          <code className="rounded bg-muted px-1.5 py-0.5 text-sm text-foreground">
            ~/Library/Application Support/DockTile/
          </code>{" "}
          - stores the generated tile apps that appear in your Dock
        </li>
      </ul>
      <p className="leading-relaxed text-muted-foreground">
        This data never leaves your computer.
      </p>

      <LegalHeading>System Access</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} requires the following system access to
        function:
      </p>
      <ul className="flex list-disc flex-col gap-2 pl-6 leading-relaxed text-muted-foreground">
        <li>
          <strong className="font-semibold text-foreground">Dock preferences</strong> -
          to add and remove tiles from your Dock
        </li>
        <li>
          <strong className="font-semibold text-foreground">
            Application Support folder
          </strong>{" "}
          - to store generated tile bundles
        </li>
        <li>
          <strong className="font-semibold text-foreground">
            Automation (optional)
          </strong>{" "}
          - to restart the Dock when tiles are added or removed
        </li>
      </ul>

      <LegalHeading>Analytics</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} includes optional, anonymous usage analytics
        and crash reporting. As a single developer, this is what helps me
        streamline the software and make it grow — it shows me which
        features matter and catches crashes I&apos;d otherwise never hear
        about.
      </p>
      <p className="leading-relaxed text-muted-foreground">
        To be upfront about what that means:
      </p>
      <ul className="flex list-disc flex-col gap-2 pl-6 leading-relaxed text-muted-foreground">
        <li>
          This data is{" "}
          <strong className="font-semibold text-foreground">
            never shared with, or sold to, advertisers or third parties
          </strong>
          .
        </li>
        <li>
          It is used strictly to improve the software and keep it stable
          — nothing else.
        </li>
        <li>
          It contains no personal information: no names, no email
          addresses, and nothing about your files.
        </li>
        <li>
          You can switch it off at any time via the{" "}
          <strong className="font-semibold text-foreground">
            &quot;Share anonymous usage data&quot;
          </strong>{" "}
          toggle in Settings → General.
        </li>
      </ul>

      <LegalHeading>Third-Party Services</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        The optional analytics above are powered by Google Firebase
        (Analytics and Crashlytics). It is the only third-party service{" "}
        {siteConfig.appName} talks to, and it receives only the anonymous
        data described above. There are no advertising SDKs and no
        trackers.
      </p>

      <LegalHeading>Updates</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        When you download updates from GitHub, GitHub may collect standard
        web server logs (IP address, browser type, etc.) as described in{" "}
        <a
          href="https://docs.github.com/en/site-policy/privacy-policies"
          target="_blank"
          rel="noopener noreferrer"
          className="font-medium text-emerald-600 underline underline-offset-4 transition-colors hover:text-emerald-500"
        >
          GitHub&apos;s Privacy Policy
        </a>
        .
      </p>

      <LegalHeading>Contact</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        If you have questions about this privacy policy, please{" "}
        <a
          href={`mailto:${siteConfig.contactEmail}`}
          className="font-medium text-emerald-600 underline underline-offset-4 transition-colors hover:text-emerald-500"
        >
          get in touch
        </a>
        .
      </p>
    </LegalShell>
  );
}
