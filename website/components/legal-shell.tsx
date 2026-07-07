import type { CSSProperties, ReactNode } from "react";
import { ContactCta } from "@/components/contact-cta";
import { Footer } from "@/components/footer";
import { Reveal } from "@/components/reveal";

/**
 * Shared treatment for legal pages (Privacy, Terms), mirroring the FAQ page:
 * a centered dark hero band (eyebrow + big headline + optional subtitle),
 * a plain light prose column (same treatment as the home feature sections —
 * no card sheet), then the FAQ's contact band and footer.
 */
export function LegalShell({
  eyebrow = "Legal",
  title,
  subtitle,
  lastUpdated,
  children,
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <main className="bg-background">
      {/* Dark hero band — same treatment as the FAQ page header */}
      <section
        data-nav-tone="dark"
        className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] bg-black px-6 pb-16 pt-28 text-center md:mx-4 md:mt-4 md:pb-20 md:pt-36"
      >
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <div className="relative z-10">
          <span
            className="reveal mb-3 block text-[12px] font-bold uppercase tracking-[0.2em] text-white/60"
            style={{ "--reveal-delay": "0ms" } as CSSProperties}
          >
            {eyebrow}
          </span>
          <h1
            className="reveal text-3xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl"
            style={{ "--reveal-delay": "80ms" } as CSSProperties}
          >
            {title}
            {subtitle && (
              <>
                <br />
                <span className="tracking-[-0.04em] text-3xl text-white/40">{subtitle}</span>
              </>
            )}
          </h1>
          <p
            className="reveal mt-4 text-sm font-light text-white/40"
            style={{ "--reveal-delay": "160ms" } as CSSProperties}
          >
            {lastUpdated}
          </p>
        </div>
      </section>

      {/* Light content section — plain prose column, like the home feature sections */}
      <section className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <Reveal>
          <div className="mx-auto flex max-w-[65ch] flex-col gap-6 text-left">
            {children}
          </div>
        </Reveal>
      </section>

      <ContactCta
        title="Questions?"
        subtitle="Send a note and you'll usually hear back within a day."
      />

      <Footer />
    </main>
  );
}

/** Section heading inside the legal prose. */
export function LegalHeading({ children }: { children: ReactNode }) {
  return (
    <h2 className="mt-4 text-xl font-bold tracking-tight text-foreground">
      {children}
    </h2>
  );
}
