import { Hero } from "@/components/hero";
import {
  SmartAddStory,
  DockLockStory,
  BentoGrid,
  FinalCta,
} from "@/components/home-sections";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="bg-zinc-100">
      <Hero />
      <SmartAddStory />
      <DockLockStory />
      <BentoGrid />
      <FinalCta />
      <Footer />
    </main>
  );
}
