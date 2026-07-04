"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { siteConfig } from "@/lib/config";
import { DownloadActionButton } from "@/components/action-button";

const navLinks = [
  { label: "Features", href: "/features" },
  { label: "FAQ", href: "/faq" },
];

export function Header() {
  const pathname = usePathname();
  const [scrolled, setScrolled] = React.useState(false);

  React.useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className="fixed top-4 left-1/2 z-50 -translate-x-1/2 md:top-6">
      <nav
        className={`glass-nav  ${scrolled ? "glass-nav--scrolled" : ""} flex items-center gap-1 rounded-full py-1.5 pl-2 pr-1.5 shadow-2xl md:gap-4 md:pl-3`}
      >
        <Link
          href="/"
          className="flex shrink-0 items-center gap-2 rounded-full py-1 pl-1 pr-1 transition-colors duration-300 hover:bg-white/10 md:pr-2"
        >
          <Image
            src="/assets/dock-tile-icon-only.svg"
            alt={siteConfig.appName}
            width={24}
            height={24}
            className="h-6 w-6 shrink-0"
          />
          <span className="hidden whitespace-nowrap text-sm font-semibold tracking-tight text-white md:inline">
            {siteConfig.appName}
          </span>
        </Link>

        <div className="flex items-center">
          {navLinks.map((link) => {
            const isActive = pathname.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-full px-2.5 py-1.5 text-[13px] transition-colors duration-300 md:px-3 ${
                  isActive
                    ? "bg-white/10 text-white"
                    : "text-white/80 hover:bg-white/10 hover:text-white"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </div>

        <DownloadActionButton tone="light" size="sm" label="Download" />
      </nav>
    </header>
  );
}
