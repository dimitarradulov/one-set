import { useState } from 'react';

import {
  APP_USER_SETUP_FAILURE_MESSAGE,
  APP_USER_SETUP_FINISH_LABEL,
  APP_USER_SETUP_FINISH_LOADING_LABEL,
} from '@/constants/app-user-setup';
import type {
  ClerkEmailPasswordSignUp,
  ClerkTokenGetter,
  CreateAccountNavigation,
} from '@/types/clerk-sign-up-flow';
import {
  finalizeClerkSignUp,
  getAuthMethodError,
  getClerkErrorMessage,
  getClerkErrorTarget,
  linkFinalizedClerkSignUp,
} from '@/utils/clerk-sign-up-flow';
import {
  getAppUserLinkingErrorMessage,
  isAppUserLinkingAuthConfigurationError,
} from '@/utils/app-user-linking';
import {
  normalizeCreateAccountEmail,
  validateCreateAccountInput,
} from '@/utils/create-account-validation';
import { clearPendingAuthFlow, setPendingAuthFlow } from '@/utils/pending-auth-flow';

const AUTH_LOADING_MESSAGE = 'Authentication is still loading. Please try again.';
const CREATE_ACCOUNT_FAILURE_MESSAGE = 'We could not create your account. Please try again.';
const CREATE_ACCOUNT_FINISH_FAILURE_MESSAGE =
  'We could not finish creating your account. Please try again.';
const CREATE_ACCOUNT_LOADING_LABEL = 'Creating account...';
const CREATE_ACCOUNT_LABEL = 'Create account';

export const useCreateAccountAuth = ({
  signUp,
  fetchStatus,
  getToken,
  router,
}: {
  signUp: ClerkEmailPasswordSignUp | null | undefined;
  fetchStatus?: string;
  getToken: ClerkTokenGetter;
  router: CreateAccountNavigation;
}) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [emailError, setEmailError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [isLocalSubmitting, setIsLocalSubmitting] = useState(false);
  const [setupClerkUserId, setSetupClerkUserId] = useState<string | null>(null);
  const [setupEmailAddress, setSetupEmailAddress] = useState<string | null>(null);

  const isClerkSubmitting = fetchStatus === 'fetching';
  const isSubmitting = isLocalSubmitting || isClerkSubmitting;
  const canCreateAccount = Boolean(signUp);
  const isSetupRecovery = Boolean(setupClerkUserId && setupEmailAddress);

  const clearSetupRecovery = () => {
    setSetupClerkUserId(null);
    setSetupEmailAddress(null);
  };

  const applyClerkError = (error: unknown, fallback: string) => {
    const message = getClerkErrorMessage(error, fallback);
    const target = getClerkErrorTarget(error);

    if (target === 'email') {
      setEmailError(message);
      return;
    }

    if (target === 'password') {
      setPasswordError(message);
      return;
    }

    setFormError(message);
  };

  const finishSetupForUser = async (clerkUserId: string, emailAddress: string) => {
    await linkFinalizedClerkSignUp({
      clerkUserId,
      email: emailAddress,
      getToken,
    });

    clearSetupRecovery();
    clearPendingAuthFlow();
    router.replace('/trial-paywall');
  };

  const handleFinishSetup = async () => {
    if (isSubmitting || !setupClerkUserId || !setupEmailAddress) {
      setFormError(AUTH_LOADING_MESSAGE);
      return;
    }

    setIsLocalSubmitting(true);
    setFormError(null);

    try {
      await finishSetupForUser(setupClerkUserId, setupEmailAddress);
    } catch (error) {
      if (__DEV__ && !isAppUserLinkingAuthConfigurationError(error)) {
        console.error(error);
      }

      setFormError(getAppUserLinkingErrorMessage(error, APP_USER_SETUP_FAILURE_MESSAGE));
    } finally {
      setIsLocalSubmitting(false);
    }
  };

  const finalizeAndLinkSignUp = async (emailAddress: string) => {
    const clerkUserId = await finalizeClerkSignUp(signUp as ClerkEmailPasswordSignUp);

    setSetupClerkUserId(clerkUserId);
    setSetupEmailAddress(emailAddress);
    setPassword('');

    await finishSetupForUser(clerkUserId, emailAddress);
  };

  const handleCreateAccount = async () => {
    if (!signUp || isSubmitting) {
      setFormError(AUTH_LOADING_MESSAGE);
      return;
    }

    const normalizedEmail = normalizeCreateAccountEmail(email);
    const validationErrors = validateCreateAccountInput({
      email: normalizedEmail,
      password,
    });

    setEmailError(validationErrors.email ?? null);
    setPasswordError(validationErrors.password ?? null);
    setFormError(validationErrors.form ?? null);

    if (validationErrors.email || validationErrors.password) {
      return;
    }

    setIsLocalSubmitting(true);
    setFormError(null);
    clearPendingAuthFlow();
    let shouldShowSetupFailure = false;

    try {
      const passwordResult = await signUp.password({
        emailAddress: normalizedEmail,
        password,
      });
      const passwordError = getAuthMethodError(passwordResult);

      if (passwordError) {
        applyClerkError(passwordError, CREATE_ACCOUNT_FAILURE_MESSAGE);
        return;
      }

      if (signUp.status === 'complete') {
        shouldShowSetupFailure = true;
        await finalizeAndLinkSignUp(normalizedEmail);
        return;
      }

      const verificationResult = await signUp.verifications.sendEmailCode();
      const verificationError = getAuthMethodError(verificationResult);

      if (verificationError) {
        applyClerkError(verificationError, CREATE_ACCOUNT_FINISH_FAILURE_MESSAGE);
        return;
      }

      setPendingAuthFlow({
        emailAddress: normalizedEmail,
      });
      router.replace('/verify-email');
    } catch (error) {
      if (__DEV__ && !isAppUserLinkingAuthConfigurationError(error)) {
        console.error(error);
      }

      if (shouldShowSetupFailure) {
        setFormError(getAppUserLinkingErrorMessage(error, APP_USER_SETUP_FAILURE_MESSAGE));
        return;
      }

      applyClerkError(error, CREATE_ACCOUNT_FAILURE_MESSAGE);
    } finally {
      setIsLocalSubmitting(false);
    }
  };

  const handlePrimaryAction = isSetupRecovery ? handleFinishSetup : handleCreateAccount;
  const primaryActionLabel = isSubmitting
    ? isSetupRecovery
      ? APP_USER_SETUP_FINISH_LOADING_LABEL
      : CREATE_ACCOUNT_LOADING_LABEL
    : isSetupRecovery
      ? APP_USER_SETUP_FINISH_LABEL
      : CREATE_ACCOUNT_LABEL;
  const isPrimaryActionDisabled = isSubmitting || (!isSetupRecovery && !canCreateAccount);

  return {
    email,
    password,
    emailError,
    passwordError,
    formError,
    primaryActionLabel,
    isPrimaryActionDisabled,
    handlePrimaryAction,
    setEmail,
    setPassword,
    setEmailError,
    setPasswordError,
    setFormError,
  };
};
