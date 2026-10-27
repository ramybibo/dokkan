import { setLocale } from "@/lib/i18n/actions";
import type { Locale } from "@/lib/i18n/dictionaries";

/** Shows the *other* language, so one tap switches between Arabic (RTL) and English (LTR). */
export function LocaleSwitcher({ locale }: { locale: Locale }) {
  const target: Locale = locale === "ar" ? "en" : "ar";
  const label = target === "ar" ? "العربية" : "English";

  return (
    <form action={setLocale}>
      <input type="hidden" name="locale" value={target} />
      <button
        type="submit"
        lang={target}
        className="min-h-11 rounded-lg border border-stone-300 bg-white px-3 text-sm font-medium text-stone-700 hover:bg-stone-100"
      >
        {label}
      </button>
    </form>
  );
}
