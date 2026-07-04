import type { Metadata } from "next";
import { LegalShell, LegalHeading } from "@/components/legal-shell";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: `Privacy Policy - ${siteConfig.appName}`,
  description: `Privacy policy for ${siteConfig.appName}, a macOS utility app.`,
};

export default function PrivacyPage() {
  return (
    <LegalShell title="Privacy Policy" lastUpdated="Last updated: February 2026">
      <p className="leading-relaxed text-zinc-600">
        {siteConfig.appName} is designed with your privacy in mind.
        Here&apos;s what you need to know:
      </p>

      <LegalHeading>Data Collection</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
        <strong className="font-semibold text-zinc-900">
          {siteConfig.appName} does not collect any personal data.
        </strong>{" "}
        The app runs entirely on your Mac and does not communicate with
        any external servers.
      </p>

      <LegalHeading>Local Storage</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
        {siteConfig.appName} stores the following data locally on your
        Mac:
      </p>
      <ul className="flex list-disc flex-col gap-2 pl-6 leading-relaxed text-zinc-600">
        <li>
          <strong className="font-semibold text-zinc-900">Configuration file</strong>:{" "}
          <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-sm text-zinc-700">
            ~/Library/Preferences/com.docktile.configs.json
          </code>{" "}
          - stores your tile settings, app lists, and customizations
        </li>
        <li>
          <strong className="font-semibold text-zinc-900">Helper bundles</strong>:{" "}
          <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-sm text-zinc-700">
            ~/Library/Application Support/DockTile/
          </code>{" "}
          - stores the generated tile apps that appear in your Dock
        </li>
      </ul>
      <p className="leading-relaxed text-zinc-600">
        This data never leaves your computer.
      </p>

      <LegalHeading>System Access</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
        {siteConfig.appName} requires the following system access to
        function:
      </p>
      <ul className="flex list-disc flex-col gap-2 pl-6 leading-relaxed text-zinc-600">
        <li>
          <strong className="font-semibold text-zinc-900">Dock preferences</strong> -
          to add and remove tiles from your Dock
        </li>
        <li>
          <strong className="font-semibold text-zinc-900">
            Application Support folder
          </strong>{" "}
          - to store generated tile bundles
        </li>
        <li>
          <strong className="font-semibold text-zinc-900">
            Automation (optional)
          </strong>{" "}
          - to restart the Dock when tiles are added or removed
        </li>
      </ul>

      <LegalHeading>Analytics</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
        {siteConfig.appName} does not include any analytics, tracking, or
        telemetry. No usage data is collected or transmitted.
      </p>

      <LegalHeading>Third-Party Services</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
        {siteConfig.appName} does not use any third-party services, SDKs,
        or frameworks that collect user data.
      </p>

      <LegalHeading>Updates</LegalHeading>
      <p className="leading-relaxed text-zinc-600">
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
      <p className="leading-relaxed text-zinc-600">
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
