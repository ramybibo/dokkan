import { test } from "node:test";
import assert from "node:assert/strict";

import { CURRENCY, formatEGP, toPiastres } from "../src/lib/currency";
import { GOVERNORATES, governorateLabel, isGovernorateKey, isValidPhone } from "../src/lib/egypt";
import {
  LOCALES,
  dictionaries,
  directionOf,
  format,
  isLocale,
} from "../src/lib/i18n/dictionaries";

function flatten(obj: unknown, prefix = ""): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === "string") out[path] = value;
    else Object.assign(out, flatten(value, path));
  }
  return out;
}

test("currency is fixed to EGP", () => {
  assert.equal(CURRENCY, "EGP");
});

test("formatEGP shows two decimals and the EGP currency in both languages", () => {
  const en = formatEGP("1234.5", "en");
  assert.match(en, /EGP/);
  assert.match(en, /1,234\.50/);

  const ar = formatEGP(1234.5, "ar");
  // Arabic-Indic digits and the Egyptian pound sign
  assert.match(ar, /١٬٢٣٤٫٥٠/);
  assert.match(ar, /ج\.م/);
});

test("formatEGP rejects non-numeric input instead of printing NaN", () => {
  assert.throws(() => formatEGP("abc", "en"), RangeError);
});

test("toPiastres is exact", () => {
  assert.equal(toPiastres("1234.50"), 123450);
  assert.equal(toPiastres("0.1"), 10);
  assert.equal(toPiastres("0.07"), 7);
  assert.equal(toPiastres("19"), 1900);
  assert.equal(toPiastres("-5.25"), -525);
  assert.throws(() => toPiastres("1.234"), RangeError);
  assert.throws(() => toPiastres("12,5"), RangeError);
});

test("both dictionaries have exactly the same keys and no empty strings", () => {
  const en = flatten(dictionaries.en);
  const ar = flatten(dictionaries.ar);
  assert.deepEqual(Object.keys(ar).sort(), Object.keys(en).sort());
  for (const locale of LOCALES) {
    for (const [key, value] of Object.entries(flatten(dictionaries[locale]))) {
      assert.ok(value.trim().length > 0, `${locale}.${key} is empty`);
    }
  }
});

test("placeholders match between Arabic and English", () => {
  const en = flatten(dictionaries.en);
  const ar = flatten(dictionaries.ar);
  for (const key of Object.keys(en)) {
    const placeholders = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join(",");
    assert.equal(placeholders(ar[key]!), placeholders(en[key]!), `placeholder mismatch at ${key}`);
  }
});

test("Arabic is RTL and English is LTR", () => {
  assert.equal(directionOf("ar"), "rtl");
  assert.equal(directionOf("en"), "ltr");
});

test("isLocale only accepts supported locales", () => {
  assert.equal(isLocale("ar"), true);
  assert.equal(isLocale("en"), true);
  assert.equal(isLocale("fr"), false);
  assert.equal(isLocale(undefined), false);
});

test("format fills placeholders and leaves unknown ones", () => {
  assert.equal(format("Hi {name}", { name: "Ramy" }), "Hi Ramy");
  assert.equal(format("Hi {other}", { name: "Ramy" }), "Hi {other}");
});

test("Egypt has 27 unique governorates with both names", () => {
  assert.equal(GOVERNORATES.length, 27);
  assert.equal(new Set(GOVERNORATES.map((g) => g.key)).size, 27);
  for (const g of GOVERNORATES) {
    assert.ok(g.ar.length > 0 && g.en.length > 0);
  }
  assert.equal(isGovernorateKey("cairo"), true);
  assert.equal(isGovernorateKey("atlantis"), false);
  assert.equal(governorateLabel("cairo", "ar"), "القاهرة");
  assert.equal(governorateLabel("cairo", "en"), "Cairo");
  assert.equal(governorateLabel(null, "en"), "-");
});

test("phone validation accepts Egyptian numbers only", () => {
  assert.equal(isValidPhone("01012345678"), true);
  assert.equal(isValidPhone("+20 101 234 5678"), true);
  assert.equal(isValidPhone("02-2345-6789"), true);
  assert.equal(isValidPhone("12345"), false);
  assert.equal(isValidPhone("abc"), false);
});
