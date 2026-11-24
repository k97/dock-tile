import type { MetadataRoute } from "next";
import { siteConfig } from "@/lib/config";

export default function sitemap(): MetadataRoute.Sitemap {
  const routes = ["/", "/faq", "/dock-lock", "/release-notes", "/privacy", "/terms", "/zh-Hans", "/zh-Hans/faq", "/zh-Hans/dock-lock"];
  return routes.map((path) => ({
    url: new URL(path, siteConfig.siteUrl).toString(),
  }));
}
