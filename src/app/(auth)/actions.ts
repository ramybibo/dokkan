"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import type { AuthState } from "@/lib/auth-state";
import { createClient } from "@/lib/supabase/server";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readCredentials(formData: FormData): { email: string; password: string } | null {
  const email = String(formData.get("email") ?? "")
    .trim()
    .toLowerCase();
  const password = String(formData.get("password") ?? "");

  if (email.length > 254 || !EMAIL_PATTERN.test(email)) return null;
  if (password.length < 8 || password.length > 72) return null;
  return { email, password };
}

async function siteOrigin(): Promise<string> {
  const configured = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (configured) return configured.replace(/\/+$/, "");

  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host");
  const proto = h.get("x-forwarded-proto") ?? "https";
  return `${proto}://${host}`;
}

export async function login(_prev: AuthState, formData: FormData): Promise<AuthState> {
  const credentials = readCredentials(formData);
  if (!credentials) return { error: "invalid_input" };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(credentials);

  // One message for every failure, so the form cannot be used to discover which emails exist.
  if (error) return { error: "invalid_credentials" };

  redirect("/");
}

export async function signup(_prev: AuthState, formData: FormData): Promise<AuthState> {
  const credentials = readCredentials(formData);
  if (!credentials) return { error: "invalid_input" };

  const fullName = String(formData.get("full_name") ?? "")
    .trim()
    .slice(0, 120);

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    ...credentials,
    options: {
      data: { full_name: fullName },
      emailRedirectTo: `${await siteOrigin()}/auth/callback`,
    },
  });

  if (error) {
    return { error: error.code === "weak_password" ? "weak_password" : "generic" };
  }

  // Email confirmation off: a session exists straight away.
  if (data.session) redirect("/");

  // Email confirmation on. The same message is shown whether or not the address already
  // existed, so signup cannot be used to probe for registered emails.
  return { info: "check_email" };
}
