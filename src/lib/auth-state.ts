export type AuthErrorCode = "invalid_input" | "invalid_credentials" | "weak_password" | "generic";

export type AuthState = {
  error?: AuthErrorCode;
  info?: "check_email";
};

export type OnboardingErrorCode = "invalid_input" | "limit" | "generic";

export type OnboardingState = {
  error?: OnboardingErrorCode;
};
