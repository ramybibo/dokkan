import type { SupabaseClient } from "@supabase/supabase-js";

export type MemberRole = "owner" | "manager" | "cashier";

export type ActiveMembership = {
  role: MemberRole;
  store: {
    id: string;
    name: string;
    governorate: string | null;
    city: string | null;
  };
};

type MembershipRow = {
  role: MemberRole;
  store:
    | { id: string; name: string; governorate: string | null; city: string | null }
    | { id: string; name: string; governorate: string | null; city: string | null }[]
    | null;
};

/**
 * The signed-in user's first active store. Row Level Security already limits what is visible;
 * the explicit user_id filter is needed because owners/managers can also see their teammates.
 * A query error is thrown on purpose: treating it as "no store" would wrongly send an
 * existing owner back to onboarding.
 */
export async function getActiveMembership(
  supabase: SupabaseClient,
  userId: string,
): Promise<ActiveMembership | null> {
  const { data, error } = await supabase
    .from("store_members")
    .select("role, store:stores(id, name, governorate, city)")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`Could not load store membership (${error.code ?? "unknown"})`);
  }
  if (!data) return null;

  const row = data as unknown as MembershipRow;
  const store = Array.isArray(row.store) ? row.store[0] : row.store;
  if (!store) return null;

  return { role: row.role, store };
}
