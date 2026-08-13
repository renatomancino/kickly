import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv, hasSupabaseEnv } from "@/lib/env";

export async function updateSession(request: NextRequest) {
  // If Supabase environment is not configured, just continue the request normally.
  if (!hasSupabaseEnv()) {
    return NextResponse.next();
  }

  // Create a single response object to set cookies/headers on.
  // Avoid mutating the incoming request object (some runtimes expose read-only cookies).
  const response = NextResponse.next();
  const { url, publishableKey } = getSupabaseEnv();
  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        // Set cookies on the response so they are sent back to the client.
        cookiesToSet.forEach(({ name, value, options }) => {
          try {
            response.cookies.set(name, value, options);
          } catch (e) {
            // In some server environments setting cookies on the Response may not be supported.
            // Don't throw — log for diagnostics and continue.
            try {
              const message = e instanceof Error ? e.message : String(e);
              console.warn("updateSession: failed to set cookie", name, message);
            } catch {}
          }
        });

        // Apply headers provided by the Supabase client to the response.
        Object.entries(headers).forEach(([key, value]) => {
          try {
            response.headers.set(key, String(value));
          } catch {}
        });
      },
    },
  });

  // Invoke getUser() to refresh session cookies if the client needs them.
  // Capture and log errors instead of silently ignoring the result.
  try {
    const { data: _user, error } = await supabase.auth.getUser();
    if (error) {
      console.warn("updateSession: supabase.auth.getUser() error:", error.message);
    }
    // Optional: _user?.user may be used for additional logic in the future.
  } catch (err) {
    console.warn("updateSession: unexpected error calling supabase.auth.getUser():", err);
  }

  return response;
}
