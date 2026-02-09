import type { Metadata } from "next";
import { Footer } from "@/components/footer";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: `Release Notes - ${siteConfig.appName}`,
  description: `Release notes and changelog for ${siteConfig.appName}, a macOS utility app.`,
};

export default function ReleaseNotesPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex-1 pt-36 pb-12 px-4">
        <main className="max-w-2xl mx-auto">
          <h1 className="text-2xl md:text-4xl font-display mb-6">Release Notes</h1>

          <div className="prose prose-neutral dark:prose-invert max-w-none space-y-8">
            {/* Version 1.0.0 */}
            <section>
              <div className="flex items-baseline gap-3 mb-4">
                <h2 className="text-2xl font-semibold m-0">Version 1.0.0</h2>
                <span className="text-sm text-muted-foreground">Coming Q1 2026</span>
              </div>
              <p className="text-muted-foreground mb-4">
                Initial release of {siteConfig.appName}.
              </p>
              <div className="space-y-4">
                <div>
                  <h3 className="text-lg font-medium mb-2">Features</h3>
                  <ul className="list-disc pl-6 text-muted-foreground space-y-1">
                    <li>Create custom Dock tiles with personalised icons</li>
                    <li>Add multiple apps to each tile for quick access</li>
                    <li>Choose from SF Symbols or emojis for tile icons</li>
                    <li>Customise icon colours with preset or custom gradients</li>
                    <li>Grid and list view layouts for tile popovers</li>
                    <li>Ghost Mode - tiles hidden from Cmd+Tab by default</li>
                    <li>App Mode - optional visibility in App Switcher with context menu support</li>
                    <li>Drag to reorder apps within tiles</li>
                    <li>Multi-select apps for batch removal</li>
                    <li>Dynamic grid sizing based on app count</li>
                    <li>Full support for macOS icon styles (Default, Dark, Clear, Tinted)</li>
                  </ul>
                </div>
              </div>
            </section>

            <p className="text-sm text-muted-foreground pt-8 border-t border-border">
              For the latest updates, follow the{" "}
              <a
                href={siteConfig.downloadUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary underline underline-offset-4 hover:text-primary/80"
              >
                GitHub releases page
              </a>
              .
            </p>
          </div>
        </main>
      </div>
      <Footer />
    </div>
  );
}
