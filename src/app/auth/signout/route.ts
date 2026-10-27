import { NextResponse, type NextRequest } from "next/server";

import { createClient } from "@/lib/supabase/server";

// POST only: a plain link or image tag must never be able to sign a user out.
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(new URL("/login", request.url), { status: 303 });
}
