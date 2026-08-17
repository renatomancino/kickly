import type { Metadata } from "next";

import { AuthForm } from "@/features/auth/auth-form";

// Niente `robots` qui: lo dichiara (auth)/layout.tsx per tutto il gruppo.
// Ridichiararlo a questo livello lo sovrascriverebbe per intero (merge shallow)
// facendo cadere il `follow: false` del layout. Rilevante soprattutto su questa
// pagina, che si raggiunge da un link di recupero contenente un token.
export const metadata: Metadata = { title: "Nuova password" };

export default function UpdatePasswordPage() {
  return <AuthForm variant="update" />;
}
