import { Children, isValidElement, type CSSProperties, type ReactNode } from "react";
import { ContactCta } from "@/components/contact-cta";
import { Footer } from "@/components/footer";
import { GuideLayout, slugify } from "@/components/guide-layout";

/**
 * Shared treatment for legal pages (Privacy, Terms), mirroring the FAQ page:
 * a centered dark hero band (eyebrow + big headline + optional subtitle), the prose in
 * GuideLayout (its "On this page" list is built from the LegalHeadings among `children`),
 * then the shared contact CTA and footer.
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
  // Every LegalHeading passed straight in becomes a contents entry, so the list can't drift from the page
  const items = Children.toArray(children).flatMap((c) =>
    isValidElement<{ children?: ReactNode }>(c) && c.type === LegalHeading && typeof c.props.children === "string"
      ? [{ id: slugify(c.props.children), title: c.props.children }]
      : [],
  );
  return (
    <main className="bg-background">
      {/* Dark hero band — same treatment as the FAQ page header */}
      <section
        data-nav-tone="dark"
        className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] border border-white/10 bg-black px-6 pb-16 pt-28 text-center md:mx-4 md:mt-4 md:pb-20 md:pt-36"
      >
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <div className="relative z-10">
          <span
            className="reveal mb-3 block text-[14px] font-semibold tracking-[0.01em] text-white/75"
            style={{ "--reveal-delay": "0ms" } as CSSProperties}
          >
            {eyebrow}
          </span>
          <h1
            className="reveal text-3xl heading-display text-white md:text-5xl"
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
            className="reveal mt-4 text-sm text-white/40"
            style={{ "--reveal-delay": "160ms" } as CSSProperties}
          >
            {lastUpdated}
          </p>
        </div>
      </section>

      {/* Prose never fades in (owner, 2026-11-24) */}
      <GuideLayout items={items} location="page_sidebar">
        <div className="flex max-w-[65ch] flex-col gap-6 text-left">{children}</div>
      </GuideLayout>

      <ContactCta
        title="Questions?"
        subtitle="Send a note and you'll usually hear back within a day."
      />

      <Footer />
    </main>
  );
}

/** Section heading inside the legal prose; a plain-text one gets an anchor id (and a contents entry). */
export function LegalHeading({ children }: { children: ReactNode }) {
  return (
    <h2 id={typeof children === "string" ? slugify(children) : undefined} className="mt-4 scroll-mt-28 text-xl font-bold tracking-tight text-foreground">
      {children}
    </h2>
  );
}
