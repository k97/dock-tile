import { Hero } from "@/components/hero";
import { Screenshot } from "@/components/screenshot";
import { FAQ } from "@/components/faq";
import { Support } from "@/components/support";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col">
      <main className="flex-1">
        <Hero />
        <Screenshot />
        <FAQ />
        <Support />
      </main>
      <Footer />
    </div>
  );
}
