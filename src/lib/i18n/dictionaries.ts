// Pure data + helpers (no Next.js imports) so they can be unit tested.

export const LOCALES = ["ar", "en"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "ar";
export const LOCALE_COOKIE = "dokkan_locale";

export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (LOCALES as readonly string[]).includes(value);
}

export function directionOf(locale: Locale): "rtl" | "ltr" {
  return locale === "ar" ? "rtl" : "ltr";
}

const en = {
  brand: { name: "DOKKAN", arabicName: "دُكّان", tagline: "Shoe store management" },
  common: {
    language: "Language",
    signOut: "Sign out",
    pleaseWait: "Please wait…",
    currencyNote: "All amounts are in Egyptian pounds (EGP).",
    optional: "optional",
    soon: "Coming in a later phase",
  },
  auth: {
    loginTitle: "Sign in",
    loginSubtitle: "Welcome back. Sign in to manage your store.",
    signupTitle: "Create your account",
    signupSubtitle: "Start with your account, then set up your store.",
    fullName: "Full name",
    email: "Email",
    password: "Password",
    passwordHint: "At least 8 characters.",
    loginButton: "Sign in",
    signupButton: "Create account",
    noAccount: "New to DOKKAN?",
    haveAccount: "Already have an account?",
    goSignup: "Create an account",
    goLogin: "Sign in",
    checkEmailTitle: "Check your email",
    checkEmailBody:
      "If this address can be registered, we sent a confirmation link to it. Open the link, then sign in.",
    errors: {
      invalid_input: "Please enter a valid email and a password of at least 8 characters.",
      invalid_credentials: "Email or password is incorrect.",
      weak_password: "This password is too weak. Use at least 8 characters with letters and numbers.",
      generic: "Something went wrong. Please try again.",
      callback: "The confirmation link is invalid or expired. Please sign in or sign up again.",
    },
  },
  onboarding: {
    title: "Set up your store",
    subtitle: "You will be the owner. You can add cashiers and managers later.",
    storeName: "Store name",
    phone: "Store phone",
    governorate: "Governorate",
    selectGovernorate: "Select a governorate",
    city: "City / area",
    address: "Address",
    submit: "Create store",
    errors: {
      invalid_input: "Please enter a store name of at least 2 characters and a valid phone number.",
      limit: "You have reached the maximum number of stores for one account.",
      generic: "Could not create the store. Please try again.",
    },
  },
  dashboard: {
    welcome: "Welcome, {name}",
    yourRole: "Your role",
    storeDetails: "Store details",
    governorate: "Governorate",
    city: "City / area",
    currency: "Currency",
    currencyValue: "Egyptian pound (EGP) - fixed",
    modulesTitle: "Modules",
    modulesNote:
      "Phase 1 delivers the foundation: accounts, store isolation and onboarding. These modules are built next and are not available yet.",
    modules: {
      products: "Products, sizes and colors",
      pos: "Point of sale",
      inventory: "Inventory",
      purchases: "Purchases and suppliers",
      expenses: "Expenses",
      shifts: "Cash shifts",
      employees: "Employees",
      reports: "Reports",
      receipts: "80 mm thermal receipts",
    },
  },
  roles: { owner: "Owner", manager: "Manager", cashier: "Cashier" },
};

export type Dictionary = typeof en;

const ar: Dictionary = {
  brand: { name: "DOKKAN", arabicName: "دُكّان", tagline: "إدارة محلات الأحذية" },
  common: {
    language: "اللغة",
    signOut: "تسجيل الخروج",
    pleaseWait: "من فضلك انتظر…",
    currencyNote: "جميع المبالغ بالجنيه المصري (EGP).",
    optional: "اختياري",
    soon: "يتوفر في مرحلة لاحقة",
  },
  auth: {
    loginTitle: "تسجيل الدخول",
    loginSubtitle: "أهلًا بعودتك. سجّل دخولك لإدارة محلك.",
    signupTitle: "إنشاء حسابك",
    signupSubtitle: "ابدأ بحسابك ثم جهّز بيانات محلك.",
    fullName: "الاسم الكامل",
    email: "البريد الإلكتروني",
    password: "كلمة المرور",
    passwordHint: "8 أحرف على الأقل.",
    loginButton: "دخول",
    signupButton: "إنشاء الحساب",
    noAccount: "جديد على دُكّان؟",
    haveAccount: "عندك حساب بالفعل؟",
    goSignup: "أنشئ حسابًا",
    goLogin: "سجّل الدخول",
    checkEmailTitle: "تحقق من بريدك الإلكتروني",
    checkEmailBody:
      "إذا كان هذا البريد قابلًا للتسجيل فقد أرسلنا إليه رابط التأكيد. افتح الرابط ثم سجّل دخولك.",
    errors: {
      invalid_input: "أدخل بريدًا إلكترونيًا صحيحًا وكلمة مرور لا تقل عن 8 أحرف.",
      invalid_credentials: "البريد الإلكتروني أو كلمة المرور غير صحيحة.",
      weak_password: "كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل تجمع بين الحروف والأرقام.",
      generic: "حدث خطأ ما. حاول مرة أخرى.",
      callback: "رابط التأكيد غير صالح أو منتهي. سجّل الدخول أو أنشئ الحساب من جديد.",
    },
  },
  onboarding: {
    title: "جهّز محلك",
    subtitle: "ستكون أنت المالك، ويمكنك إضافة الكاشير والمديرين لاحقًا.",
    storeName: "اسم المحل",
    phone: "هاتف المحل",
    governorate: "المحافظة",
    selectGovernorate: "اختر المحافظة",
    city: "المدينة / المنطقة",
    address: "العنوان",
    submit: "إنشاء المحل",
    errors: {
      invalid_input: "أدخل اسم محل لا يقل عن حرفين ورقم هاتف صحيحًا.",
      limit: "وصلت إلى الحد الأقصى لعدد المحلات في حساب واحد.",
      generic: "تعذّر إنشاء المحل. حاول مرة أخرى.",
    },
  },
  dashboard: {
    welcome: "أهلًا، {name}",
    yourRole: "صلاحيتك",
    storeDetails: "بيانات المحل",
    governorate: "المحافظة",
    city: "المدينة / المنطقة",
    currency: "العملة",
    currencyValue: "الجنيه المصري (EGP) - ثابتة",
    modulesTitle: "الأقسام",
    modulesNote:
      "المرحلة الأولى تضع الأساس: الحسابات وعزل بيانات المحلات وإعداد المحل. الأقسام التالية تُبنى لاحقًا وغير متاحة الآن.",
    modules: {
      products: "المنتجات والمقاسات والألوان",
      pos: "نقطة البيع",
      inventory: "المخزون",
      purchases: "المشتريات والموردون",
      expenses: "المصروفات",
      shifts: "ورديات الخزينة",
      employees: "الموظفون",
      reports: "التقارير",
      receipts: "إيصالات حرارية 80 مم",
    },
  },
  roles: { owner: "مالك", manager: "مدير", cashier: "كاشير" },
};

export const dictionaries: Record<Locale, Dictionary> = { en, ar };

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}

/** Replaces {placeholders}; unknown placeholders are left untouched. */
export function format(template: string, values: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) => values[key] ?? match);
}
