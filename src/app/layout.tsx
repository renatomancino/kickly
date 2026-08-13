import type { Metadata } from "next";
import "./globals.css";
import { Geist, Geist_Mono } from "next/font/google";
import { cn } from "@/lib/utils";
import { siteConfig } from "@/config/site";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";

const geist = Geist({ subsets: ["latin"], variable: "--font-geist-sans" });
const geistMono = Geist_Mono({ subsets: ["latin"], variable: "--font-geist-mono" });

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: { default: siteConfig.name, template: `%s · ${siteConfig.name}` },
  description: siteConfig.description,
  applicationName: siteConfig.name,
  formatDetection: { telephone: false },
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/icons/kickly-icon-192.png", type: "image/png", sizes: "192x192" },
      { url: "/icons/kickly-icon-512.png", type: "image/png", sizes: "512x512" },
    ],
    apple: [{ url: "/icons/apple-touch-icon.png", type: "image/png", sizes: "180x180" }],
  },
  appleWebApp: { capable: true, statusBarStyle: "black", title: "Kickly" },
  openGraph: {
    type: "website",
    locale: "it_IT",
    siteName: "Kickly",
    title: "Kickly · Il calcio, organizzato",
    description: siteConfig.description,
    images: [{ url: "/opengraph-image", width: 1200, height: 630, alt: "Kickly - Your game. Your story." }],
  },
  twitter: { card: "summary_large_image", title: "Kickly · Il calcio, organizzato", description: siteConfig.description, images: ["/opengraph-image"] },
};

export const viewport = {
  themeColor: "#c7ff3d",
  colorScheme: "dark",
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="it" className={cn("dark", geist.variable, geistMono.variable)}>
      <body className="min-h-dvh overflow-x-hidden antialiased"><TooltipProvider>{children}<Toaster richColors theme="dark" /></TooltipProvider></body>
    </html>
  );
}
