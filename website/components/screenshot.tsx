"use client";

import * as React from "react";
import Image from "next/image";
import Autoplay from "embla-carousel-autoplay";

import { ChevronLeft, ChevronRight } from "lucide-react";

import {
  Carousel,
  CarouselContent,
  CarouselItem,
  type CarouselApi,
} from "@/components/ui/carousel";

const slides = [
  {
    src: "/assets/stage/dock-tiles.webp",
    alt: "Dock tiles in the macOS Dock",
    blur: "data:image/webp;base64,UklGRkIAAABXRUJQVlA4IDYAAAAQAgCdASoKAAcABUB8JbACdLoAAnSVIa3gAP3tWc8L7HbL2LVW4fqGXD6o8bjior7eBSOGYAA=",
  },
  {
    src: "/assets/stage/docktile-app.webp",
    alt: "Dock Tile app main view",
    blur: "data:image/webp;base64,UklGRkoAAABXRUJQVlA4ID4AAAAwAgCdASoKAAcABUB8JbACdLoAAxkufIs8QAD+yaHBU1kTkt0ut2QGf6YEdQy4x8aG0eI1BNpDzmg7z4AAAA==",
  },
  {
    src: "/assets/stage/icon-customiser.webp",
    alt: "Dock Tile icon customiser",
    blur: "data:image/webp;base64,UklGRkgAAABXRUJQVlA4IDwAAAAwAgCdASoKAAcABUB8JbACdLoAAxkWXIswIAD+yaTPmXkAFpuoFIj865rf+7dK2T4qKvg8gYtPREAAAAA=",
  },
];

export function ScreenCapCarousel() {
  const [api, setApi] = React.useState<CarouselApi>();
  const [current, setCurrent] = React.useState(0);
  const [hovered, setHovered] = React.useState(false);

  React.useEffect(() => {
    if (!api) return;

    setCurrent(api.selectedScrollSnap());
    api.on("select", () => {
      setCurrent(api.selectedScrollSnap());
    });
  }, [api]);

  return (
    <section className="px-4 py-8 md:py-12 max-w-4xl mx-auto">
      <div
        className="relative rounded-4xl overflow-hidden shadow-2xl dark:shadow-black/40 border border-border"
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <Carousel
          setApi={setApi}
          opts={{ loop: true }}
          plugins={[
            Autoplay({ delay: 5000, stopOnInteraction: false }),
          ]}
        >
          <CarouselContent className="ml-0">
            {slides.map((slide, index) => (
              <CarouselItem key={index} className="pl-0">
                <Image
                  src={slide.src}
                  alt={slide.alt}
                  width={2048}
                  height={1374}
                  className="w-full h-auto block"
                  placeholder="blur"
                  blurDataURL={slide.blur}
                  sizes="(max-width: 896px) 100vw, 896px"
                  unoptimized
                  priority={index === 0}
                />
              </CarouselItem>
            ))}
          </CarouselContent>
        </Carousel>

        {/* Arrow buttons — visible on hover */}
        <button
          onClick={() => api?.scrollPrev()}
          className={`absolute left-3 top-1/2 -translate-y-1/2 size-8 rounded-full bg-background/80 backdrop-blur-sm border border-border flex items-center justify-center text-foreground/70 hover:text-foreground hover:bg-background transition-all duration-200 ${
            hovered ? "opacity-100" : "opacity-0 pointer-events-none"
          }`}
          aria-label="Previous slide"
        >
          <ChevronLeft className="size-4" />
        </button>
        <button
          onClick={() => api?.scrollNext()}
          className={`absolute right-3 top-1/2 -translate-y-1/2 size-8 rounded-full bg-background/80 backdrop-blur-sm border border-border flex items-center justify-center text-foreground/70 hover:text-foreground hover:bg-background transition-all duration-200 ${
            hovered ? "opacity-100" : "opacity-0 pointer-events-none"
          }`}
          aria-label="Next slide"
        >
          <ChevronRight className="size-4" />
        </button>
      </div>

      {/* Dot indicators */}
      <div className="flex justify-center gap-2 mt-4">
        {slides.map((_, index) => (
          <button
            key={index}
            onClick={() => api?.scrollTo(index)}
            className={`h-2 rounded-full transition-all duration-300 ${
              index === current
                ? "w-6 bg-foreground"
                : "w-2 bg-foreground/25"
            }`}
            aria-label={`Go to slide ${index + 1}`}
          />
        ))}
      </div>
    </section>
  );
}
