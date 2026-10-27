import type { Metadata, Viewport } from "next";

import { directionOf } from "@/lib/i18n/dictionaries";
import { getLocale } from "@/lib/i18n/server";

import "./globals.css";

export const metadata: Metadata = {
  title: { default: "DOKKAN | دُكّان", template: "%s | DOKKAN" },
  description: "Shoe store management for Egypt | إدارة محلات الأحذية في مصر",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#0f766e",
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();

  return (
    <html lang={locale} dir={directionOf(locale)}>
      <body className="min-h-dvh font-sans">{children}</body>
    </html>
  );
}
