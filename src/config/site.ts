export const siteConfig = {
  name: "Kickly",
  shortName: "Kickly",
  description:
    "Organizza partite, vivi la tua lega e fai crescere la tua player card.",
  url: process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000",
  supportEmail: "support@kickly.app",
  defaultLocale: "it-IT",
  defaultTimezone: "Europe/Rome",
} as const;

export type SiteConfig = typeof siteConfig;
