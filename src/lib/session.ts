import { cache } from "react";
import { redirect } from "next/navigation";

import { getActiveMembership } from "./membership";
import { createClient } from "./supabase/server";

/**
 * Per-request context for signed-in pages. `cache` makes the layout and the page share one
 * lookup instead of querying twice. Signed-out visitors are sent to the login page.
 */
export const getAppContext = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const membership = await getActiveMembership(supabase, user.id);
  const metaName = user.user_metadata?.full_name;
  const displayName =
    typeof metaName === "string" && metaName.trim() ? metaName.trim() : (user.email ?? "");

  return { supabase, user, membership, displayName };
});
