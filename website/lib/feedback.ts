import { siteConfig } from "@/lib/config";

// Pre-filled GitHub issues for the footer and the FAQ. Both labels exist in the
// repo; GitHub applies them only for people allowed to label, so the title
// prefix is what sorts a report for everyone else.
function newIssue(params: Record<string, string>) {
  const query = Object.entries(params)
    .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
    .join("&");
  return `${siteConfig.githubUrl}/issues/new?${query}`;
}

// Issues are public and diagnostics list the reporter's tiles and apps, so the
// template sends them to the support inbox instead of into the issue.
const bugBody = `### What happened?


### What did you expect instead?


### Steps to reproduce
1.

### Setup
- Dock Tile version (Dock Tile ▸ About):
- macOS version:

<!-- Diagnostics help most: File ▸ Copy Diagnostics in Dock Tile. They list your tiles and apps, so please email them to ${siteConfig.contactEmail} with this issue's link rather than pasting them here. -->
`;

export const featureRequestUrl = newIssue({ labels: "enhancement", title: "Feature request: " });
export const bugReportUrl = newIssue({ labels: "bug", title: "Bug: ", body: bugBody });
