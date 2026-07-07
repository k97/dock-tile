import { Hero } from "@/components/hero";
import {
  CustomTilesStory,
  PowerUserSection,
  DockLockStory,
  FinalCta,
} from "@/components/home-sections";
import { Footer } from "@/components/footer";
import { JsonLd } from "@/components/json-ld";
import { softwareApplicationSchema } from "@/lib/schema";

export default function Home() {
  return (
    <main className="bg-background">
      <JsonLd data={softwareApplicationSchema} />
      <Hero />
      <CustomTilesStory />
      <DockLockStory />
      <PowerUserSection />
      <FinalCta />
      <Footer />
    </main>
  );
}
