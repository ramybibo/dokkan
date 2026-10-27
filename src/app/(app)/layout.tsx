import { redirect } from "next/navigation";

import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { getServerDictionary } from "@/lib/i18n/server";
import { getAppContext } from "@/lib/session";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const { membership } = await getAppContext();
  if (!membership) redirect("/onboarding");

  const { locale, t } = await getServerDictionary();

  return (
    <div className="min-h-dvh">
      <header className="border-b border-stone-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <div className="min-w-0">
            <p className="text-sm font-extrabold tracking-wide text-teal-800">{t.brand.name}</p>
            <p className="truncate text-base font-semibold">{membership.store.name}</p>
          </div>
          <div className="flex items-center gap-2">
            <LocaleSwitcher locale={locale} />
            <form action="/auth/signout" method="post">
              <button
                type="submit"
                className="min-h-11 rounded-lg border border-stone-300 bg-white px-3 text-sm font-medium text-stone-700 hover:bg-stone-100"
              >
                {t.common.signOut}
              </button>
            </form>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-6">{children}</main>
    </div>
  );
}
