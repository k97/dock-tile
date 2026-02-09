"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { Download, Loader2, Check, Mail } from "lucide-react";
import { siteConfig } from "@/lib/config";
import { trackDownloadClick, trackContactClick } from "@/lib/analytics";

type DownloadState = "ready" | "downloading" | "downloaded";

const navLinks = [
  { label: "Home", href: "/" },
  { label: "FAQ", href: "/faq" },
];

export function Header() {
  const pathname = usePathname();
  const isHomepage = pathname === "/";
  const [visible, setVisible] = React.useState(!isHomepage);

  React.useEffect(() => {
    if (!isHomepage) {
      setVisible(true);
      return;
    }

    const cta = document.getElementById("hero-cta");
    if (!cta) {
      setVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        // Show header when the download button is NOT intersecting (scrolled past)
        setVisible(!entry.isIntersecting);
      },
      { threshold: 0 }
    );

    observer.observe(cta);
    return () => observer.disconnect();
  }, [isHomepage]);

  // Handle smooth scroll for anchor links on the same page
  const handleClick = (
    e: React.MouseEvent<HTMLAnchorElement>,
    href: string
  ) => {
    if (href.startsWith("/#") && isHomepage) {
      e.preventDefault();
      const id = href.slice(2);
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: "smooth" });
      }
    }
  };

  const [downloadState, setDownloadState] = React.useState<DownloadState>("ready");

  const handleDownload = () => {
    if (downloadState !== "ready") return;
    trackDownloadClick();
    setDownloadState("downloading");
    window.location.href = siteConfig.downloadUrl;
    setTimeout(() => {
      setDownloadState("downloaded");
      setTimeout(() => setDownloadState("ready"), 4000);
    }, 2000);
  };

  return (
    <header
      className={`fixed top-4 left-1/2 -translate-x-1/2 z-50 transition-all duration-300 ease-out ${
        visible
          ? "opacity-100 translate-y-0"
          : "opacity-0 -translate-y-4 pointer-events-none"
      }`}
    >
      <nav className="flex items-center gap-4 md:gap-8 px-1.5 py-1.5 rounded-full bg-background/70 backdrop-blur-xl border border-border/50 shadow-[0_2px_20px_rgba(0,0,0,0.06)] dark:shadow-[0_2px_20px_rgba(0,0,0,0.3)]">
        {/* Brand */}
        <Link
          href="/"
          className="flex items-center gap-2 pl-2 pr-3 py-1.5 rounded-full hover:bg-accent/60 transition-colors"
        >
          <Image
            src="/assets/dock-tile-icon-only.svg"
            alt={siteConfig.appName}
            width={24}
            height={24}
            className="w-6 h-6 shrink-0"
          />
          <span className="hidden md:inline text-sm font-semibold tracking-tight">
            {siteConfig.appName}
          </span>
        </Link>

        {/* Nav links */}
        <div className="flex items-center gap-1">
          {navLinks.map((link) => {
            const isActive =
              link.href === "/"
                ? pathname === "/"
                : pathname.startsWith(link.href.replace("/#", "/"));

            return (
              <Link
                key={link.href}
                href={link.href}
                onClick={(e) => handleClick(e, link.href)}
                className={`px-3 py-1.5 rounded-full text-sm transition-colors ${
                  isActive
                    ? "text-foreground font-medium"
                    : "text-muted-foreground hover:text-foreground hover:bg-accent/60"
                }`}
              >
                {link.label}
              </Link>
            );
          })}

          {/* Support — click opens mailto, hover shows email tooltip */}
          <div className="relative group inline-flex">
            <a
              href={`mailto:${siteConfig.contactEmail}`}
              onClick={trackContactClick}
              className="px-3 py-1.5 rounded-full text-sm text-muted-foreground hover:text-foreground hover:bg-accent/60 transition-colors inline-block"
            >
              Support
            </a>
            <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 px-3 py-2 rounded-lg bg-background/90 backdrop-blur-xl border border-border/50 shadow-[0_4px_24px_rgba(0,0,0,0.1)] dark:shadow-[0_4px_24px_rgba(0,0,0,0.4)] opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity whitespace-nowrap">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Mail className="h-3 w-3" />
                {siteConfig.contactEmail}
              </div>
            </div>
          </div>
        </div>

        {/* Download CTA */}
        <button
          onClick={handleDownload}
          disabled={downloadState !== "ready"}
          className={`flex items-center gap-1.5 px-4 py-1.5 ml-1 rounded-full text-sm font-medium transition-colors ${
            downloadState === "ready"
              ? "bg-primary text-primary-foreground hover:bg-primary/90 cursor-pointer"
              : "bg-primary/70 text-primary-foreground cursor-default"
          }`}
        >
          {downloadState === "ready" && (
            <>
              <Download className="h-3.5 w-3.5" />
              Download
            </>
          )}
          {downloadState === "downloading" && (
            <>
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
              Downloading...
            </>
          )}
          {downloadState === "downloaded" && (
            <>
              <Check className="h-3.5 w-3.5" />
              Downloaded
            </>
          )}
        </button>
      </nav>
    </header>
  );
}
