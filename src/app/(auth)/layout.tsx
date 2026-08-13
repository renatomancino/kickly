import type { ReactNode } from "react";
import Link from "next/link";

import { BrandMark } from "@/components/brand-mark";
import { siteConfig } from "@/config/site";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="relative min-h-dvh overflow-hidden bg-background">
      <div aria-hidden="true" className="absolute inset-0 bg-[radial-gradient(circle_at_75%_20%,color-mix(in_oklch,var(--primary)_15%,transparent),transparent_32%)]" />
      <div className="relative mx-auto flex min-h-dvh max-w-6xl flex-col px-5 py-6 sm:px-8">
        <Link className="flex w-fit items-center gap-3 font-bold" href="/">
          <BrandMark />
          <span>{siteConfig.name}</span>
        </Link>
        <div className="flex flex-1 items-center justify-center py-12">{children}</div>
      </div>
    </main>
  );
}
