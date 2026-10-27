import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { OnboardingForm } from "@/components/OnboardingForm";
import { GOVERNORATES } from "@/lib/egypt";
import { getServerDictionary } from "@/lib/i18n/server";
import { getAppContext } from "@/lib/session";

import { createStore } from "./actions";

export const metadata: Metadata = { title: "Set up your store | جهّز محلك" };

export default async function OnboardingPage() {
  const { membership } = await getAppContext();
  if (membership) redirect("/dashboard");

  const { locale, t } = await getServerDictionary();

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-4 py-6">
      <div className="flex items-center justify-between">
        <p className="text-2xl font-extrabold tracking-wide text-teal-800">{t.brand.name}</p>
        <LocaleSwitcher locale={locale} />
      </div>

      <div className="mt-8 rounded-2xl border border-stone-200 bg-white p-5 shadow-sm sm:p-6">
        <OnboardingForm
          action={createStore}
          governorates={GOVERNORATES.map((g) => ({ key: g.key, label: g[locale] }))}
          labels={{
            title: t.onboarding.title,
            subtitle: t.onboarding.subtitle,
            storeName: t.onboarding.storeName,
            phone: t.onboarding.phone,
            governorate: t.onboarding.governorate,
            selectGovernorate: t.onboarding.selectGovernorate,
            city: t.onboarding.city,
            address: t.onboarding.address,
            optional: t.common.optional,
            submit: t.onboarding.submit,
            pending: t.common.pleaseWait,
            errors: t.onboarding.errors,
          }}
        />
      </div>

      <p className="mt-4 text-center text-xs text-stone-500">{t.common.currencyNote}</p>
    </main>
  );
}
