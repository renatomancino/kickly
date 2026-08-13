import type { Metadata } from "next";

import { AuthForm } from "@/features/auth/auth-form";

export const metadata: Metadata = { title: "Recupera password", robots: { index: false } };

export default function ForgotPasswordPage() {
  return <AuthForm variant="forgot" />;
}
