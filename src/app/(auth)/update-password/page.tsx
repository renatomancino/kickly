import type { Metadata } from "next";

import { AuthForm } from "@/features/auth/auth-form";

export const metadata: Metadata = { title: "Nuova password", robots: { index: false } };

export default function UpdatePasswordPage() {
  return <AuthForm variant="update" />;
}
