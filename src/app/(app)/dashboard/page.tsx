import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { governorateLabel } from "@/lib/egypt";
import { format } from "@/lib/i18n/dictionaries";
import { getServerDictionary } from "@/lib/i18n/server";
import { getAppContext } from "@/lib/session";

export const metadata: Metadata = { title: "Dashboard | لوحة التحكم" };

export default async function DashboardPage() {
  const { membership, displayName } = await getAppContext();
  if (!membership) redirect("/onboarding");

  const { locale, t } = await getServerDictionary();
  const { store, role } = membership;
  const modules = Object.values(t.dashboard.modules);

  return (
    <div className="space-y-6">
      <section>
        <h1 className="text-2xl font-bold">{format(t.dashboard.welcome, { name: displayName })}</h1>
        <p className="mt-1 text-sm text-stone-600">
          {t.dashboard.yourRole}:{" "}
          <span className="rounded-full bg-teal-50 px-2 py-0.5 font-semibold text-teal-800">
            {t.roles[role]}
          </span>
        </p>
      </section>

      <section className="rounded-2xl border border-stone-200 bg-white p-5">
        <h2 className="text-lg font-semibold">{t.dashboard.storeDetails}</h2>
        <dl className="mt-3 grid gap-3 sm:grid-cols-2">
          <div>
            <dt className="text-sm text-stone-500">{t.onboarding.storeName}</dt>
            <dd className="font-medium">{store.name}</dd>
          </div>
          <div>
            <dt className="text-sm text-stone-500">{t.dashboard.governorate}</dt>
            <dd className="font-medium">{governorateLabel(store.governorate, locale)}</dd>
          </div>
          <div>
            <dt className="text-sm text-stone-500">{t.dashboard.city}</dt>
            <dd className="font-medium">{store.city ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-sm text-stone-500">{t.dashboard.currency}</dt>
            <dd className="font-medium">{t.dashboard.currencyValue}</dd>
          </div>
        </dl>
      </section>

      <section className="rounded-2xl border border-dashed border-stone-300 bg-white p-5">
        <h2 className="text-lg font-semibold">{t.dashboard.modulesTitle}</h2>
        <p className="mt-1 text-sm text-stone-600">{t.dashboard.modulesNote}</p>
        <ul className="mt-4 grid gap-2 sm:grid-cols-2">
          {modules.map((label) => (
            <li
              key={label}
              className="flex items-center justify-between gap-3 rounded-lg bg-stone-100 px-3 py-2 text-sm text-stone-500"
            >
              <span>{label}</span>
              <span className="shrink-0 text-xs">{t.common.soon}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
