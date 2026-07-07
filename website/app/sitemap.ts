import type { MetadataRoute } from "next";
import { siteConfig } from "@/lib/config";

export default function sitemap(): MetadataRoute.Sitemap {
  const routes = ["/", "/faq", "/release-notes", "/privacy", "/terms"];
  return routes.map((path) => ({
    url: new URL(path, siteConfig.siteUrl).toString(),
  }));
}
