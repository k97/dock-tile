"use client";

import { LegalShell, LegalHeading } from "@/components/legal-shell";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";

const link =
  "font-medium text-emerald-600 underline decoration-emerald-600/40 underline-offset-4 transition-colors hover:text-emerald-500 hover:decoration-emerald-500 dark:text-emerald-400 dark:decoration-emerald-400/40 dark:hover:text-emerald-300 dark:hover:decoration-emerald-300";
const body = "leading-relaxed text-muted-foreground";

// The licence section defers to the repo's LICENSE (MIT). Until 2026-11-09 it
// said the app could not be redistributed, modified or sold, which the MIT
// License itself permits.
export function TermsContent() {
  const { content } = useLocale();

  return (
    <LegalShell
      eyebrow="Terms"
      title="Terms of Use"
      lastUpdated="Last updated: November 2026"
    >
      <p className={body}>
        By downloading and using {siteConfig.appName}, you agree to the following terms:
      </p>

      <LegalHeading>{content.legal.licenceHeading}</LegalHeading>
      <p className={body}>
        {siteConfig.appName} is open source under the{" "}
        <a href={`${siteConfig.githubUrl}/blob/main/LICENSE`} target="_blank" rel="noopener noreferrer" className={link}>
          MIT License
        </a>
        . You may use, copy, modify and distribute it under its terms, which include keeping its
        copyright and permission notice.
      </p>

      <LegalHeading>Disclaimer of Warranties</LegalHeading>
      <p className={body}>
        {siteConfig.appName} is provided &quot;as is&quot; without warranty of any kind, express or
        implied. {siteConfig.authorName} does not warrant that the software will be error-free or
        uninterrupted.
      </p>

      <LegalHeading>Limitation of Liability</LegalHeading>
      <p className={body}>
        In no event shall {siteConfig.authorName} be liable for any damages arising out of the use
        or inability to use {siteConfig.appName}, including but not limited to direct, indirect,
        incidental, or consequential damages.
      </p>

      <LegalHeading>What the app does on your Mac</LegalHeading>
      <p className={body}>
        To work, {siteConfig.appName} creates small helper apps for your tiles, changes your Dock
        and restarts it to apply those changes, starts your tiles at login (unless you switch that
        off), and, only if you turn on Dock Lock, uses Accessibility access. The{" "}
        <a href="/privacy" className={link}>
          Privacy Policy
        </a>{" "}
        explains each of these. By using the app, you consent to them.
      </p>

      <LegalHeading>Updates</LegalHeading>
      <p className={body}>
        {siteConfig.appName} checks for new versions once a day and installs them automatically in
        the background.
      </p>

      <LegalHeading>Changes</LegalHeading>
      <p className={body}>
        These terms may be updated from time to time. Continued use of {siteConfig.appName} after
        changes constitutes acceptance of the new terms.
      </p>

      <LegalHeading>Contact</LegalHeading>
      <p className={body}>
        If you have questions about these terms, please{" "}
        <a href={`mailto:${siteConfig.contactEmail}`} className={link}>
          get in touch
        </a>
        .
      </p>
    </LegalShell>
  );
}
