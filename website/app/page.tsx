import { Hero } from "@/components/hero";
import {
  CustomTilesStory,
  PowerUserSection,
  DockLockStory,
  FinalCta,
} from "@/components/home-sections";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="bg-background">
      <Hero />
      <CustomTilesStory />
      <DockLockStory />
      <PowerUserSection />
      <FinalCta />
      <Footer />
    </main>
  );
}
