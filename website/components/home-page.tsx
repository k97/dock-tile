import { Hero } from "@/components/hero";
import {
  CustomTilesStory,
  IntroSection,
  DockLockStory,
  PowerUserSection,
} from "@/components/home-sections";
import { DownloadSection } from "@/components/download-section";
import { HomeFaq } from "@/components/home-faq";
import { Footer } from "@/components/footer";
import { JsonLd } from "@/components/json-ld";
import { HeroVeil } from "@/components/hero-veil";
import { HERO_BG, HERO_BG_DARK } from "@/lib/assets";

/** The homepage, shared by "/" and "/zh-Hans" (the route's locale picks the copy). */
export function HomePage({ schema }: { schema: Record<string, unknown> }) {
  return (
    <>
      {/* Preload the theme-matched hero wallpaper at top priority so it's
          decoded before first paint instead of popping in late — the flash the
          veil hides while this lands. `media` fetches only the scheme shown, and
          React hoists these <link>s into <head>. */}
      <link
        rel="preload"
        as="image"
        fetchPriority="high"
        type="image/webp"
        href={HERO_BG}
        media="(prefers-color-scheme: light)"
      />
      <link
        rel="preload"
        as="image"
        fetchPriority="high"
        type="image/webp"
        href={HERO_BG_DARK}
        media="(prefers-color-scheme: dark)"
      />
      <HeroVeil />
      <main className="bg-background">
        <JsonLd data={schema} />
        <Hero />
        <IntroSection />
        <PowerUserSection />
        <CustomTilesStory />
        <DockLockStory />
        <HomeFaq />
        <DownloadSection />
        <Footer />
      </main>
    </>
  );
}
