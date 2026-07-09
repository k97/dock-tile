import { Hero } from "@/components/hero";
import {
  CustomTilesStory,
  PowerUserSection,
  DockLockStory,
  FinalCta,
} from "@/components/home-sections";
import { Footer } from "@/components/footer";
import { JsonLd } from "@/components/json-ld";
import { HeroVeil } from "@/components/hero-veil";
import { softwareApplicationSchema } from "@/lib/schema";
import { asset } from "@/lib/assets";

export default function Home() {
  return (
    <>
      {/* Preload the theme-matched hero wallpaper at top priority so it's
          decoded before first paint instead of popping in late — the flash the
          veil hides while this lands. `media` fetches only the scheme shown, and
          React hoists these <link>s into <head>. */}
      <link
        rel="preload"
        as="image"
        type="image/webp"
        href={asset("/assets/hero-bg.webp")}
        media="(prefers-color-scheme: light)"
      />
      <link
        rel="preload"
        as="image"
        type="image/webp"
        href={asset("/assets/hero-bg-dark.webp")}
        media="(prefers-color-scheme: dark)"
      />
      <HeroVeil />
      <main className="bg-background">
        <JsonLd data={softwareApplicationSchema} />
        <Hero />
        <CustomTilesStory />
        <DockLockStory />
        <PowerUserSection />
        <FinalCta />
        <Footer />
      </main>
    </>
  );
}
