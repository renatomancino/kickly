import type { Metadata } from "next";

import { AuthForm } from "@/features/auth/auth-form";

// Niente `robots` qui: lo dichiara (auth)/layout.tsx per tutto il gruppo.
// Ridichiararlo a questo livello lo sovrascriverebbe per intero (merge shallow)
// facendo cadere il `follow: false` del layout.
export const metadata: Metadata = { title: "Recupera password" };

export default function ForgotPasswordPage() {
  return <AuthForm variant="forgot" />;
}
