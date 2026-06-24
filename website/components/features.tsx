"use client";

import * as React from "react";
import {
  Palette,
  MousePointerClick,
  Lock,
  type LucideIcon,
} from "lucide-react";
import { useLocale } from "@/components/locale-provider";

// Icon + tint pairing for each feature, matched by index to the localised
// `features` array in i18n.ts. The tinted chips echo Dock Tile's own
// colourful tiles rather than a flat monochrome grid.
const featureMeta: { icon: LucideIcon; tint: string }[] = [
  { icon: MousePointerClick, tint: "from-sky-400/25 to-indigo-300/25 text-sky-500 dark:text-sky-300" },
  { icon: Lock, tint: "from-amber-400/25 to-yellow-300/25 text-amber-500 dark:text-amber-300" },
  { icon: Palette, tint: "from-rose-400/25 to-orange-300/25 text-rose-500 dark:text-rose-300" },
];

export function Features() {
  const { content } = useLocale();

  return (
    <section
      id="features"
      className="scroll-mt-24 px-4 py-12 md:py-16 max-w-5xl mx-auto"
    >
      <div className="text-center mb-10 md:mb-12">
        <h2 className="text-2xl md:text-3xl font-display">
          {content.featuresTitle}
        </h2>
        <p className="mt-3 text-muted-foreground">{content.featuresSubtitle}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {content.features.map((feature, index) => {
          const meta = featureMeta[index % featureMeta.length];
          const Icon = meta.icon;
          return (
            <div
              key={feature.title}
              className="group relative rounded-3xl border border-white/20 dark:border-white/10 bg-white/70 dark:bg-white/[0.06] backdrop-blur-xl p-6 shadow-[0_4px_24px_rgba(0,0,0,0.06)] dark:shadow-[0_4px_24px_rgba(0,0,0,0.3)] transition-transform duration-200 ease-out hover:-translate-y-0.5"
            >
              {/* Inner highlight for glass effect, matching the hero icon */}
              <div className="pointer-events-none absolute inset-0 rounded-3xl bg-gradient-to-b from-white/40 to-transparent dark:from-white/[0.06] dark:to-transparent" />

              <div className="relative">
                <div
                  className={`flex size-11 items-center justify-center rounded-2xl bg-gradient-to-br ${meta.tint} ring-1 ring-inset ring-white/30 dark:ring-white/10`}
                >
                  <Icon className="size-5" strokeWidth={2} />
                </div>

                <h3 className="mt-4 text-base font-semibold tracking-tight">
                  {feature.title}
                </h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                  {feature.description}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
