"use client";

import * as React from "react";
import Image from "next/image";

export function Screenshot() {
  const [hasError, setHasError] = React.useState(false);

  return (
    <section className="px-4 py-8 md:py-12 max-w-4xl mx-auto">
      <div className="relative rounded-4xl overflow-hidden shadow-2xl dark:shadow-black/40 border border-border">
        {!hasError ? (
          <Image
            src="/assets/dock-tile-stage.png"
            alt="Dock Tile app screenshot"
            width={1400}
            height={750}
            className="w-full h-auto"
            onError={() => setHasError(true)}
          />
        ) : (
          <div className="flex flex-col items-center justify-center gap-2 min-h-[300px] bg-muted text-muted-foreground">
            <span className="font-medium">App Screenshot</span>
            <span className="text-sm">Add screenshot.png to public/assets</span>
          </div>
        )}
      </div>
    </section>
  );
}
