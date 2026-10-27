import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { getServerDictionary } from "@/lib/i18n/server";

export default async function AuthLayout({ children }: { children: React.ReactNode }) {
  const { locale, t } = await getServerDictionary();

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-4 py-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-2xl font-extrabold tracking-wide text-teal-800">{t.brand.name}</p>
          <p className="text-sm text-stone-600">
            {t.brand.arabicName} · {t.brand.tagline}
          </p>
        </div>
        <LocaleSwitcher locale={locale} />
      </div>

      <div className="mt-8 rounded-2xl border border-stone-200 bg-white p-5 shadow-sm sm:p-6">
        {children}
      </div>

      <p className="mt-4 text-center text-xs text-stone-500">{t.common.currencyNote}</p>
    </main>
  );
}
