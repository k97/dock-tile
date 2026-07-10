"use client";

import { LegalShell, LegalHeading } from "@/components/legal-shell";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";

export function TermsContent() {
  const { content } = useLocale();

  return (
    <LegalShell
      eyebrow="Terms"
      title="Terms of Use"
      lastUpdated="Last updated: February 2026"
    >
      <p className="leading-relaxed text-muted-foreground">
        By downloading and using {siteConfig.appName}, you agree to the
        following terms:
      </p>

      <LegalHeading>{content.legal.licenceHeading}</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} is provided as-is for personal use. You may
        not redistribute, modify, or sell the software without explicit
        permission.
      </p>

      <LegalHeading>Disclaimer of Warranties</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} is provided &quot;as is&quot; without
        warranty of any kind, express or implied. The developer does not
        warrant that the software will be error-free or uninterrupted.
      </p>

      <LegalHeading>Limitation of Liability</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        In no event shall the developer be liable for any damages arising
        out of the use or inability to use {siteConfig.appName}, including
        but not limited to direct, indirect, incidental, or consequential
        damages.
      </p>

      <LegalHeading>System Access</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        {siteConfig.appName} requires access to system preferences and the
        ability to create helper applications to function. By using the
        app, you acknowledge and consent to these requirements.
      </p>

      <LegalHeading>Changes</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        These terms may be updated from time to time. Continued use of{" "}
        {siteConfig.appName} after changes constitutes acceptance of the
        new terms.
      </p>

      <LegalHeading>Contact</LegalHeading>
      <p className="leading-relaxed text-muted-foreground">
        If you have questions about these terms, please{" "}
        <a
          href={`mailto:${siteConfig.contactEmail}`}
          className="font-medium text-emerald-600 underline decoration-emerald-600/40 underline-offset-4 transition-colors hover:text-emerald-500 hover:decoration-emerald-500 dark:text-emerald-400 dark:decoration-emerald-400/40 dark:hover:text-emerald-300 dark:hover:decoration-emerald-300"
        >
          get in touch
        </a>
        .
      </p>
    </LegalShell>
  );
}
