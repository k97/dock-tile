import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Assets are served from the Cloudflare R2 CDN in production (see lib/assets.ts).
    // next/image must be told the host is trusted or an optimized <Image> src from
    // R2 is rejected. Local dev serves from public/, so this is a no-op there.
    remotePatterns: [
      {
        protocol: "https",
        hostname: "pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev",
        pathname: "/**",
      },
    ],
  },
};

export default nextConfig;
