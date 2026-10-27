"use server";

import { redirect } from "next/navigation";

import type { OnboardingState } from "@/lib/auth-state";
import { isGovernorateKey, isValidPhone } from "@/lib/egypt";
import { getActiveMembership } from "@/lib/membership";
import { createClient } from "@/lib/supabase/server";

function field(formData: FormData, name: string, max: number): string {
  return String(formData.get(name) ?? "")
    .trim()
    .slice(0, max);
}

export async function createStore(
  _prev: OnboardingState,
  formData: FormData,
): Promise<OnboardingState> {
  const name = field(formData, "name", 120);
  const phone = field(formData, "phone", 20);
  const governorate = field(formData, "governorate", 40);
  const city = field(formData, "city", 80);
  const address = field(formData, "address", 300);

  if (name.length < 2) return { error: "invalid_input" };
  if (phone && !isValidPhone(phone)) return { error: "invalid_input" };
  if (governorate && !isGovernorateKey(governorate)) return { error: "invalid_input" };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // A double tap or a second tab must not create a second store by accident.
  if (await getActiveMembership(supabase, user.id)) redirect("/dashboard");

  // One database function creates the store and the owner membership in a single transaction.
  const { error } = await supabase.rpc("create_store", {
    p_name: name,
    p_phone: phone || null,
    p_governorate: governorate || null,
    p_city: city || null,
    p_address: address || null,
  });

  if (error) {
    if (error.code === "P0001") return { error: "limit" };
    if (error.code === "22023") return { error: "invalid_input" };
    return { error: "generic" };
  }

  redirect("/dashboard");
}
