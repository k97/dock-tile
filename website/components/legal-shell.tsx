import type { ReactNode } from "react";
import { Footer } from "@/components/footer";
import { Reveal } from "@/components/reveal";

/**
 * Shared treatment for legal pages (Privacy, Terms): dark shell header with
 * the LEGAL eyebrow, then a light white content sheet with readable prose.
 */
export function LegalShell({
  title,
  lastUpdated,
  children,
}: {
  title: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <main className="bg-zinc-100">
      <section className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] bg-black pb-6 pt-28 md:mx-4 md:mt-4 md:pb-8 md:pt-36">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />

        {/* Dark header */}
        <div className="relative z-10 mx-auto w-full max-w-4xl px-6 md:px-8">
          <Reveal className="mb-12">
            <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400">
              Legal
            </span>
            <h1 className="mb-4 text-4xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-6xl">
              {title}
            </h1>
            <p className="text-sm font-light text-white/40">{lastUpdated}</p>
          </Reveal>

          {/* Light content sheet */}
          <Reveal delay={100}>
            <article className="rounded-[2.5rem] bg-white p-8 shadow-2xl md:p-16">
              <div className="mx-auto flex max-w-[65ch] flex-col gap-6">
                {children}
              </div>
            </article>
          </Reveal>
        </div>
      </section>

      <Footer />
    </main>
  );
}

/** Section heading inside the legal sheet. */
export function LegalHeading({ children }: { children: ReactNode }) {
  return (
    <h2 className="mt-4 text-xl font-bold tracking-tight text-zinc-900">
      {children}
    </h2>
  );
}
