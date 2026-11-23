// The Chinese test pages. shortcut: <html lang="en"> stays (the root layout can't see the route
// without making every page dynamic), so the content carries lang itself; the header sits
// outside it. Upgrade to a [lang] segment if the test grows past / and /faq.
export default function ZhLayout({ children }: { children: React.ReactNode }) {
  return <div lang="zh-Hans">{children}</div>;
}
