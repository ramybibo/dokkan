import { redirect } from "next/navigation";

import { getAppContext } from "@/lib/session";

// Entry point: decide where a signed-in user belongs. Signed-out users never get here
// (the middleware sends them to /login), and getAppContext double-checks.
export default async function Home() {
  const { membership } = await getAppContext();
  redirect(membership ? "/dashboard" : "/onboarding");
}
