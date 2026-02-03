import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Footer } from "@/components/footer";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: `Terms of Use - ${siteConfig.appName}`,
  description: `Terms of use for ${siteConfig.appName}, a macOS utility app.`,
};

export default function TermsPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex-1 py-12 px-4">
        <main className="max-w-2xl mx-auto">
        <Button variant="outline" size="lg" className="mb-8 -ml-2 rounded-xl" asChild>
          <Link href="/">
            <ArrowLeft className="h-4 w-4 mr-1.5" />
            Back to {siteConfig.appName}
          </Link>
        </Button>

        <h1 className="text-4xl font-display mb-6">Terms of Use</h1>

        <div className="prose prose-neutral dark:prose-invert max-w-none space-y-6">
          <p className="text-muted-foreground">
            By downloading and using {siteConfig.appName}, you agree to the
            following terms:
          </p>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">License</h2>
            <p className="text-muted-foreground">
              {siteConfig.appName} is provided as-is for personal use. You may
              not redistribute, modify, or sell the software without explicit
              permission.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">
              Disclaimer of Warranties
            </h2>
            <p className="text-muted-foreground">
              {siteConfig.appName} is provided &quot;as is&quot; without
              warranty of any kind, express or implied. The developer does not
              warrant that the software will be error-free or uninterrupted.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">
              Limitation of Liability
            </h2>
            <p className="text-muted-foreground">
              In no event shall the developer be liable for any damages arising
              out of the use or inability to use {siteConfig.appName}, including
              but not limited to direct, indirect, incidental, or consequential
              damages.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">System Access</h2>
            <p className="text-muted-foreground">
              {siteConfig.appName} requires access to system preferences and the
              ability to create helper applications to function. By using the
              app, you acknowledge and consent to these requirements.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Changes</h2>
            <p className="text-muted-foreground">
              These terms may be updated from time to time. Continued use of{" "}
              {siteConfig.appName} after changes constitutes acceptance of the
              new terms.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold mt-8 mb-3">Contact</h2>
            <p className="text-muted-foreground">
              If you have questions about these terms, please{" "}
              <a
                href={`mailto:${siteConfig.contactEmail}`}
                className="text-primary underline underline-offset-4 hover:text-primary/80"
              >
                get in touch
              </a>
              .
            </p>
          </section>

          <p className="text-sm text-muted-foreground pt-8  mt-12">
            Last updated: February 2026
          </p>
        </div>
        </main>
      </div>
      <Footer />
    </div>
  );
}
