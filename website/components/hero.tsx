"use client";

import * as React from "react";
import Image from "next/image";
import { Download, Loader2, Check } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackDownloadClick, trackReleaseNotesClick } from "@/lib/analytics";

export function Hero() {
  const { content } = useLocale();
  const iconRef = React.useRef<HTMLDivElement>(null);

  // Download button state machine
  const [downloadState, setDownloadState] = React.useState<'ready' | 'downloading' | 'downloaded'>('ready');

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!iconRef.current) return;

    const rect = iconRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const rotateX = (y - centerY) / 10;
    const rotateY = (centerX - x) / 10;

    iconRef.current.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.05)`;
  };

  const handleMouseLeave = () => {
    if (!iconRef.current) return;
    iconRef.current.style.transform =
      "perspective(1000px) rotateX(0) rotateY(0) scale(1)";
  };

  const handleDownload = () => {
    // Track analytics
    trackDownloadClick();

    // Change to downloading state
    setDownloadState('downloading');

    // Initiate download
    window.location.href = siteConfig.downloadUrl;

    // After 2 seconds, assume download started and show "Downloaded"
    setTimeout(() => {
      setDownloadState('downloaded');

      // After 4 more seconds, reset to ready
      setTimeout(() => {
        setDownloadState('ready');
      }, 4000);
    }, 2000);
  };

  return (
    <section id="hero-section" className="flex flex-col items-center text-center px-4 pt-16 pb-8 md:pt-24 md:pb-12">
      {/* App Icon with 3D tilt effect and macOS glass styling */}
      <div
        ref={iconRef}
        className="w-32 h-32 md:w-40 md:h-40 transition-transform duration-200 ease-out will-change-transform"
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
      >
        {/* macOS-style glass container */}
        <div className="relative w-full h-full rounded-[22%] bg-white/80 dark:bg-white/10 backdrop-blur-xl shadow-[0_8px_32px_rgba(0,0,0,0.12),0_2px_8px_rgba(0,0,0,0.08)] dark:shadow-[0_8px_32px_rgba(0,0,0,0.4),0_2px_8px_rgba(0,0,0,0.2)] border border-white/20 dark:border-white/10 overflow-hidden">
          {/* Inner highlight for glass effect */}
          <div className="absolute inset-0 rounded-[22%] bg-gradient-to-b from-white/40 to-transparent dark:from-white/10 dark:to-transparent pointer-events-none" />

          {/* SVG Icon centered */}
          <div className="absolute inset-0 flex items-center justify-center p-5">
            <Image
              src="/assets/dock-tile-icon-only.svg"
              alt={`${siteConfig.appName} icon`}
              width={120}
              height={120}
              className="w-full h-full object-contain"
              priority
            />
          </div>
        </div>
      </div>

      {/* App Name - uses Special Gothic font */}
      <h1 className="mt-6 text-4xl md:text-5xl font-display tracking-tight">
        {siteConfig.appName}
      </h1>

      {/* Tagline */}
      <p className="mt-3 text-lg md:text-xl text-muted-foreground">
        {content.tagline}
      </p>

      {/* Description */}
      <p className="mt-4 max-w-lg text-muted-foreground">
        {content.description}
      </p>

      {/* CTA Buttons */}
      <div id="hero-cta" className="mt-8 flex flex-col sm:flex-row items-center gap-3">
        <Button
          size="lg"
          onClick={handleDownload}
          disabled={downloadState !== 'ready'}
          className="gap-2 px-8 py-6 rounded-xl text-md cursor-pointer"
        >
          {downloadState === 'ready' && (
            <>
              <Download className="h-4 w-4" />
              {content.downloadButton}
            </>
          )}
          {downloadState === 'downloading' && (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Downloading...
            </>
          )}
          {downloadState === 'downloaded' && (
            <>
              <Check className="h-4 w-4" />
              Downloaded
            </>
          )}
        </Button>
      </div>

      {/* Version & System Requirements */}
      <p className="mt-4 text-sm text-muted-foreground">
        <a
          href={siteConfig.releaseNotesUrl}
          className="text-foreground hover:underline underline-offset-4"
          onClick={trackReleaseNotesClick}
        >
          v{siteConfig.latestVersion}
        </a>
        {" · Free · macOS 26+"}
      </p>
    </section>
  );
}
