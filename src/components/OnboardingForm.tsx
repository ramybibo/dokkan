"use client";

import { useActionState } from "react";

import type { OnboardingState } from "@/lib/auth-state";

import { SubmitButton } from "./SubmitButton";

type Labels = {
  title: string;
  subtitle: string;
  storeName: string;
  phone: string;
  governorate: string;
  selectGovernorate: string;
  city: string;
  address: string;
  optional: string;
  submit: string;
  pending: string;
  errors: Record<string, string>;
};

const inputClass =
  "mt-1 block min-h-11 w-full rounded-lg border border-stone-300 bg-white px-3 py-2 text-base text-stone-900";

export function OnboardingForm({
  action,
  labels,
  governorates,
}: {
  action: (prev: OnboardingState, formData: FormData) => Promise<OnboardingState>;
  labels: Labels;
  governorates: { key: string; label: string }[];
}) {
  const [state, formAction] = useActionState<OnboardingState, FormData>(action, {});
  const errorText = state.error ? (labels.errors[state.error] ?? labels.errors.generic) : undefined;

  return (
    <form action={formAction} className="space-y-4">
      <div>
        <h1 className="text-xl font-bold">{labels.title}</h1>
        <p className="mt-1 text-sm text-stone-600">{labels.subtitle}</p>
      </div>

      {errorText ? (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          {errorText}
        </p>
      ) : null}

      <label className="block text-sm font-medium">
        {labels.storeName}
        <input name="name" type="text" required minLength={2} maxLength={120} className={inputClass} />
      </label>

      <label className="block text-sm font-medium">
        {labels.phone} <span className="font-normal text-stone-500">({labels.optional})</span>
        <input
          name="phone"
          type="tel"
          dir="ltr"
          inputMode="tel"
          autoComplete="tel"
          maxLength={20}
          className={`${inputClass} text-start`}
        />
      </label>

      <label className="block text-sm font-medium">
        {labels.governorate} <span className="font-normal text-stone-500">({labels.optional})</span>
        <select name="governorate" defaultValue="" className={inputClass}>
          <option value="">{labels.selectGovernorate}</option>
          {governorates.map((g) => (
            <option key={g.key} value={g.key}>
              {g.label}
            </option>
          ))}
        </select>
      </label>

      <label className="block text-sm font-medium">
        {labels.city} <span className="font-normal text-stone-500">({labels.optional})</span>
        <input name="city" type="text" maxLength={80} className={inputClass} />
      </label>

      <label className="block text-sm font-medium">
        {labels.address} <span className="font-normal text-stone-500">({labels.optional})</span>
        <input name="address" type="text" maxLength={300} className={inputClass} />
      </label>

      <SubmitButton pendingLabel={labels.pending}>{labels.submit}</SubmitButton>
    </form>
  );
}
