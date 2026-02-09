import type { Metadata } from "next";
import { Footer } from "@/components/footer";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: `Privacy Policy - ${siteConfig.appName}`,
  description: `Privacy policy for ${siteConfig.appName}, a macOS utility app.`,
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex-1 pt-26 pb-12 px-4">
        <main className="max-w-2xl mx-auto">
        <h1 className="text-xl md:text-3xl font-display mb-12 text-center">Privacy Policy</h1>

        <div className="prose prose-neutral dark:prose-invert max-w-none space-y-6">
          <p className="text-muted-foreground">
            {siteConfig.appName} is designed with your privacy in mind.
            Here&apos;s what you need to know:
          </p>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Data Collection</h2>
            <p className="text-muted-foreground">
              <strong className="text-foreground">
                {siteConfig.appName} does not collect any personal data.
              </strong>{" "}
              The app runs entirely on your Mac and does not communicate with
              any external servers.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Local Storage</h2>
            <p className="text-muted-foreground mb-3">
              {siteConfig.appName} stores the following data locally on your
              Mac:
            </p>
            <ul className="list-disc pl-6 text-muted-foreground space-y-2">
              <li>
                <strong className="text-foreground">Configuration file</strong>:{" "}
                <code className="text-sm bg-muted px-1.5 py-0.5 rounded">
                  ~/Library/Preferences/com.docktile.configs.json
                </code>{" "}
                - stores your tile settings, app lists, and customizations
              </li>
              <li>
                <strong className="text-foreground">Helper bundles</strong>:{" "}
                <code className="text-sm bg-muted px-1.5 py-0.5 rounded">
                  ~/Library/Application Support/DockTile/
                </code>{" "}
                - stores the generated tile apps that appear in your Dock
              </li>
            </ul>
            <p className="text-muted-foreground mt-3">
              This data never leaves your computer.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">System Access</h2>
            <p className="text-muted-foreground mb-3">
              {siteConfig.appName} requires the following system access to
              function:
            </p>
            <ul className="list-disc pl-6 text-muted-foreground space-y-2">
              <li>
                <strong className="text-foreground">Dock preferences</strong> -
                to add and remove tiles from your Dock
              </li>
              <li>
                <strong className="text-foreground">
                  Application Support folder
                </strong>{" "}
                - to store generated tile bundles
              </li>
              <li>
                <strong className="text-foreground">
                  Automation (optional)
                </strong>{" "}
                - to restart the Dock when tiles are added or removed
              </li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Analytics</h2>
            <p className="text-muted-foreground">
              {siteConfig.appName} does not include any analytics, tracking, or
              telemetry. No usage data is collected or transmitted.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">
              Third-Party Services
            </h2>
            <p className="text-muted-foreground">
              {siteConfig.appName} does not use any third-party services, SDKs,
              or frameworks that collect user data.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Updates</h2>
            <p className="text-muted-foreground">
              When you download updates from GitHub, GitHub may collect standard
              web server logs (IP address, browser type, etc.) as described in{" "}
              <a
                href="https://docs.github.com/en/site-policy/privacy-policies"
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary underline underline-offset-4 hover:text-primary/80"
              >
                GitHub&apos;s Privacy Policy
              </a>
              .
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Contact</h2>
            <p className="text-muted-foreground">
              If you have questions about this privacy policy, please{" "}
              <a
                href={`mailto:${siteConfig.contactEmail}`}
                className="text-primary underline underline-offset-4 hover:text-primary/80"
              >
                get in touch
              </a>
              .
            </p>
          </section>

          <p className="text-sm text-muted-foreground pt-8 mt-12">
            Last updated: February 2026
          </p>
        </div>
        </main>
      </div>
      <Footer />
    </div>
  );
}
