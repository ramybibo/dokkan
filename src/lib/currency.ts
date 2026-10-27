import type { Locale } from "./i18n/dictionaries";

/** DOKKAN is Egypt-only: the currency is fixed and intentionally not configurable. */
export const CURRENCY = "EGP" as const;

const formatters: Record<Locale, Intl.NumberFormat> = {
  ar: new Intl.NumberFormat("ar-EG", {
    style: "currency",
    currency: CURRENCY,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }),
  en: new Intl.NumberFormat("en-EG", {
    style: "currency",
    currency: CURRENCY,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }),
};

/** Formats an EGP amount. Accepts the numeric(12,2) string Postgres returns, or a number. */
export function formatEGP(amount: number | string, locale: Locale): string {
  const value = typeof amount === "string" ? Number(amount) : amount;
  if (!Number.isFinite(value)) {
    throw new RangeError(`Invalid EGP amount: ${String(amount)}`);
  }
  return formatters[locale].format(value);
}

/** Converts a decimal EGP string ("1234.50") to integer piastres without float error. */
export function toPiastres(amount: string): number {
  const match = /^(-?)(\d{1,12})(?:\.(\d{1,2}))?$/.exec(amount.trim());
  if (!match) {
    throw new RangeError(`Invalid EGP amount: ${amount}`);
  }
  const [, sign, pounds, fraction = ""] = match;
  const piastres = Number(pounds) * 100 + Number(fraction.padEnd(2, "0"));
  return sign === "-" ? -piastres : piastres;
}
