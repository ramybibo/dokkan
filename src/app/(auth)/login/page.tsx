import type { Metadata } from "next";

import { AuthForm } from "@/components/AuthForm";
import { getServerDictionary } from "@/lib/i18n/server";

import { login } from "../actions";

export const metadata: Metadata = { title: "Sign in | تسجيل الدخول" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { t } = await getServerDictionary();
  const { error } = await searchParams;

  return (
    <AuthForm
      mode="login"
      action={login}
      initialError={error === "callback" ? "callback" : undefined}
      labels={{
        title: t.auth.loginTitle,
        subtitle: t.auth.loginSubtitle,
        fullName: t.auth.fullName,
        email: t.auth.email,
        password: t.auth.password,
        passwordHint: t.auth.passwordHint,
        submit: t.auth.loginButton,
        pending: t.common.pleaseWait,
        switchPrompt: t.auth.noAccount,
        switchLabel: t.auth.goSignup,
        switchHref: "/signup",
        checkEmailTitle: t.auth.checkEmailTitle,
        checkEmailBody: t.auth.checkEmailBody,
        errors: t.auth.errors,
      }}
    />
  );
}
