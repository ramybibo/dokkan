import type { Metadata } from "next";

import { AuthForm } from "@/components/AuthForm";
import { getServerDictionary } from "@/lib/i18n/server";

import { signup } from "../actions";

export const metadata: Metadata = { title: "Create account | إنشاء حساب" };

export default async function SignupPage() {
  const { t } = await getServerDictionary();

  return (
    <AuthForm
      mode="signup"
      action={signup}
      labels={{
        title: t.auth.signupTitle,
        subtitle: t.auth.signupSubtitle,
        fullName: t.auth.fullName,
        email: t.auth.email,
        password: t.auth.password,
        passwordHint: t.auth.passwordHint,
        submit: t.auth.signupButton,
        pending: t.common.pleaseWait,
        switchPrompt: t.auth.haveAccount,
        switchLabel: t.auth.goLogin,
        switchHref: "/login",
        checkEmailTitle: t.auth.checkEmailTitle,
        checkEmailBody: t.auth.checkEmailBody,
        errors: t.auth.errors,
      }}
    />
  );
}
