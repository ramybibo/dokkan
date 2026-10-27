"use client";

import Link from "next/link";
import { useActionState } from "react";

import type { AuthState } from "@/lib/auth-state";

import { SubmitButton } from "./SubmitButton";

type Labels = {
  title: string;
  subtitle: string;
  fullName: string;
  email: string;
  password: string;
  passwordHint: string;
  submit: string;
  pending: string;
  switchPrompt: string;
  switchLabel: string;
  switchHref: string;
  checkEmailTitle: string;
  checkEmailBody: string;
  errors: Record<string, string>;
};

const inputClass =
  "mt-1 block min-h-11 w-full rounded-lg border border-stone-300 bg-white px-3 py-2 text-base text-stone-900 placeholder:text-stone-400";

export function AuthForm({
  mode,
  action,
  labels,
  initialError,
}: {
  mode: "login" | "signup";
  action: (prev: AuthState, formData: FormData) => Promise<AuthState>;
  labels: Labels;
  initialError?: string;
}) {
  const [state, formAction] = useActionState<AuthState, FormData>(action, {});

  if (state.info === "check_email") {
    return (
      <div role="status" className="space-y-3 text-center">
        <h1 className="text-xl font-bold">{labels.checkEmailTitle}</h1>
        <p className="text-stone-600">{labels.checkEmailBody}</p>
        <Link href="/login" className="inline-block font-semibold text-teal-700 underline">
          {labels.switchLabel}
        </Link>
      </div>
    );
  }

  const errorKey = state.error ?? initialError;
  const errorText = errorKey ? (labels.errors[errorKey] ?? labels.errors.generic) : undefined;

  return (
    <form action={formAction} className="space-y-4" noValidate={false}>
      <div>
        <h1 className="text-xl font-bold">{labels.title}</h1>
        <p className="mt-1 text-sm text-stone-600">{labels.subtitle}</p>
      </div>

      {errorText ? (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          {errorText}
        </p>
      ) : null}

      {mode === "signup" ? (
        <label className="block text-sm font-medium">
          {labels.fullName}
          <input
            name="full_name"
            type="text"
            autoComplete="name"
            maxLength={120}
            className={inputClass}
          />
        </label>
      ) : null}

      <label className="block text-sm font-medium">
        {labels.email}
        <input
          name="email"
          type="email"
          dir="ltr"
          required
          autoComplete="email"
          inputMode="email"
          className={`${inputClass} text-start`}
        />
      </label>

      <label className="block text-sm font-medium">
        {labels.password}
        <input
          name="password"
          type="password"
          dir="ltr"
          required
          minLength={8}
          maxLength={72}
          autoComplete={mode === "signup" ? "new-password" : "current-password"}
          className={`${inputClass} text-start`}
        />
        {mode === "signup" ? (
          <span className="mt-1 block text-xs font-normal text-stone-500">{labels.passwordHint}</span>
        ) : null}
      </label>

      <SubmitButton pendingLabel={labels.pending}>{labels.submit}</SubmitButton>

      <p className="text-center text-sm text-stone-600">
        {labels.switchPrompt}{" "}
        <Link href={labels.switchHref} className="font-semibold text-teal-700 underline">
          {labels.switchLabel}
        </Link>
      </p>
    </form>
  );
}
