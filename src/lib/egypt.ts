import type { Locale } from "./i18n/dictionaries";

/** The 27 governorates of Egypt. The stable `key` is what gets stored in the database. */
export const GOVERNORATES = [
  { key: "cairo", ar: "القاهرة", en: "Cairo" },
  { key: "giza", ar: "الجيزة", en: "Giza" },
  { key: "alexandria", ar: "الإسكندرية", en: "Alexandria" },
  { key: "qalyubia", ar: "القليوبية", en: "Qalyubia" },
  { key: "port-said", ar: "بورسعيد", en: "Port Said" },
  { key: "suez", ar: "السويس", en: "Suez" },
  { key: "dakahlia", ar: "الدقهلية", en: "Dakahlia" },
  { key: "sharqia", ar: "الشرقية", en: "Sharqia" },
  { key: "gharbia", ar: "الغربية", en: "Gharbia" },
  { key: "monufia", ar: "المنوفية", en: "Monufia" },
  { key: "beheira", ar: "البحيرة", en: "Beheira" },
  { key: "kafr-el-sheikh", ar: "كفر الشيخ", en: "Kafr El Sheikh" },
  { key: "damietta", ar: "دمياط", en: "Damietta" },
  { key: "ismailia", ar: "الإسماعيلية", en: "Ismailia" },
  { key: "faiyum", ar: "الفيوم", en: "Faiyum" },
  { key: "beni-suef", ar: "بني سويف", en: "Beni Suef" },
  { key: "minya", ar: "المنيا", en: "Minya" },
  { key: "asyut", ar: "أسيوط", en: "Asyut" },
  { key: "sohag", ar: "سوهاج", en: "Sohag" },
  { key: "qena", ar: "قنا", en: "Qena" },
  { key: "luxor", ar: "الأقصر", en: "Luxor" },
  { key: "aswan", ar: "أسوان", en: "Aswan" },
  { key: "red-sea", ar: "البحر الأحمر", en: "Red Sea" },
  { key: "new-valley", ar: "الوادي الجديد", en: "New Valley" },
  { key: "matrouh", ar: "مطروح", en: "Matrouh" },
  { key: "north-sinai", ar: "شمال سيناء", en: "North Sinai" },
  { key: "south-sinai", ar: "جنوب سيناء", en: "South Sinai" },
] as const;

const KEYS: readonly string[] = GOVERNORATES.map((g) => g.key);

export function isGovernorateKey(value: string): boolean {
  return KEYS.includes(value);
}

export function governorateLabel(key: string | null | undefined, locale: Locale): string {
  if (!key) return "-";
  const found = GOVERNORATES.find((g) => g.key === key);
  return found ? found[locale] : key;
}

/** Egyptian mobile (01xxxxxxxxx) or landline with optional +20, spaces and dashes allowed. */
export function isValidPhone(value: string): boolean {
  const compact = value.replace(/[\s-]/g, "");
  return /^(\+?20|0)\d{8,10}$/.test(compact);
}
