import { useAuth, useSignUp } from '@clerk/expo';
import { useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { KeyboardAvoidingView, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import {
  APP_USER_SETUP_FAILURE_MESSAGE,
  APP_USER_SETUP_FINISH_LABEL,
  APP_USER_SETUP_FINISH_LOADING_LABEL,
} from '@/constants/app-user-setup';
import {
  VERIFY_EMAIL_CODE_LENGTH,
  VERIFY_EMAIL_RESEND_ACTION_LABEL,
  VERIFY_EMAIL_RESEND_COOLDOWN_SECONDS,
  VERIFY_EMAIL_RESEND_FAILURE_MESSAGE,
  VERIFY_EMAIL_RESEND_LOADING_LABEL,
} from '@/constants/verify-email';
import type { ClerkEmailPasswordSignUp } from '@/types/clerk-sign-up-flow';
import {
  finalizeClerkSignUp,
  getAuthMethodError,
  getClerkErrorMessage,
  linkFinalizedClerkSignUp,
} from '@/utils/clerk-sign-up-flow';
import {
  getAppUserLinkingErrorMessage,
  isAppUserLinkingAuthConfigurationError,
} from '@/utils/app-user-linking';
import { clearPendingAuthFlow, getPendingAuthFlow } from '@/utils/pending-auth-flow';

const normalizeVerificationCode = (value: string): string =>
  value.replace(/\D/g, '').slice(0, VERIFY_EMAIL_CODE_LENGTH);

export default function VerifyEmailScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { getToken } = useAuth();
  const { signUp, fetchStatus } = useSignUp();
  const emailPasswordSignUp = signUp as ClerkEmailPasswordSignUp | null | undefined;
  const pendingAuthFlow = getPendingAuthFlow();
  const verificationCodeInputRef = useRef<TextInput>(null);
  const [code, setCode] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isVerifying, setIsVerifying] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [resendCooldownSeconds, setResendCooldownSeconds] = useState(0);
  const [setupClerkUserId, setSetupClerkUserId] = useState<string | null>(null);
  const [setupEmailAddress, setSetupEmailAddress] = useState<string | null>(null);
  const isSetupRecovery = Boolean(setupClerkUserId && setupEmailAddress);

  const clearSetupRecovery = () => {
    setSetupClerkUserId(null);
    setSetupEmailAddress(null);
  };

  const handleFinishSetup = async () => {
    if (isVerifying || !setupClerkUserId || !setupEmailAddress) {
      setErrorMessage('Authentication is still loading. Please try again.');
      return;
    }

    setIsVerifying(true);
    setErrorMessage(null);

    try {
      await linkFinalizedClerkSignUp({
        clerkUserId: setupClerkUserId,
        email: setupEmailAddress,
        getToken,
      });

      clearSetupRecovery();
      clearPendingAuthFlow();
      router.replace('/trial-paywall');
    } catch (error) {
      if (__DEV__ && !isAppUserLinkingAuthConfigurationError(error)) {
        console.error(error);
      }

      setErrorMessage(getAppUserLinkingErrorMessage(error, APP_USER_SETUP_FAILURE_MESSAGE));
    } finally {
      setIsVerifying(false);
    }
  };

  useEffect(() => {
    if (resendCooldownSeconds === 0) {
      return;
    }

    const interval = setInterval(() => {
      setResendCooldownSeconds((current) => Math.max(current - 1, 0));
    }, 1000);

    return () => clearInterval(interval);
  }, [resendCooldownSeconds]);

  useEffect(() => {
    if (!emailPasswordSignUp || !pendingAuthFlow) {
      clearPendingAuthFlow();
      router.replace('/create-account');
    }
  }, [emailPasswordSignUp, pendingAuthFlow, router]);

  if (!emailPasswordSignUp || !pendingAuthFlow) {
    return null;
  }

  const handleVerifyEmail = async () => {
    if (isVerifying || isResending || code.length !== VERIFY_EMAIL_CODE_LENGTH) {
      return;
    }

    setIsVerifying(true);
    setErrorMessage(null);
    let shouldShowSetupFailure = false;

    try {
      const verificationResult = await emailPasswordSignUp.verifications.verifyEmailCode({
        code,
      });
      const verificationError = getAuthMethodError(verificationResult);

      if (verificationError) {
        setCode('');
        setErrorMessage(
          getClerkErrorMessage(
            verificationError,
            'We could not verify your email. Please try again.'
          )
        );
        return;
      }

      if (emailPasswordSignUp.status !== 'complete') {
        setCode('');
        setErrorMessage('We could not verify your email. Please try again.');
        return;
      }

      const verifiedUserId = await finalizeClerkSignUp(emailPasswordSignUp);

      setSetupClerkUserId(verifiedUserId);
      setSetupEmailAddress(pendingAuthFlow.emailAddress);
      shouldShowSetupFailure = true;

      await linkFinalizedClerkSignUp({
        clerkUserId: verifiedUserId,
        email: pendingAuthFlow.emailAddress,
        getToken,
      });

      clearSetupRecovery();
      clearPendingAuthFlow();
      router.replace('/trial-paywall');
    } catch (error) {
      if (__DEV__ && !isAppUserLinkingAuthConfigurationError(error)) {
        console.error(error);
      }

      setCode('');
      setErrorMessage(
        shouldShowSetupFailure
          ? getAppUserLinkingErrorMessage(error, APP_USER_SETUP_FAILURE_MESSAGE)
          : getClerkErrorMessage(error, 'We could not verify your email. Please try again.')
      );
    } finally {
      setIsVerifying(false);
    }
  };

  const handleResendCode = async () => {
    if (isVerifying || isResending || !emailPasswordSignUp) {
      setErrorMessage('Authentication is still loading. Please try again.');
      return;
    }

    setIsResending(true);
    setErrorMessage(null);

    try {
      const resendResult = await emailPasswordSignUp.verifications.sendEmailCode();
      const resendError = getAuthMethodError(resendResult);

      if (resendError) {
        setErrorMessage(getClerkErrorMessage(resendError, VERIFY_EMAIL_RESEND_FAILURE_MESSAGE));
        return;
      }

      setResendCooldownSeconds(VERIFY_EMAIL_RESEND_COOLDOWN_SECONDS);
    } catch (error) {
      if (__DEV__) {
        console.error(error);
      }

      setErrorMessage(getClerkErrorMessage(error, VERIFY_EMAIL_RESEND_FAILURE_MESSAGE));
    } finally {
      setIsResending(false);
    }
  };

  const handlePrimaryAction = isSetupRecovery ? handleFinishSetup : handleVerifyEmail;
  const primaryActionLabel = isVerifying
    ? isSetupRecovery
      ? APP_USER_SETUP_FINISH_LOADING_LABEL
      : 'Verifying...'
    : isSetupRecovery
      ? APP_USER_SETUP_FINISH_LABEL
      : 'Verify email';
  const isPrimaryActionDisabled =
    isVerifying ||
    isResending ||
    fetchStatus === 'fetching' ||
    (!isSetupRecovery && code.length !== VERIFY_EMAIL_CODE_LENGTH) ||
    (!emailPasswordSignUp && isSetupRecovery);
  const resendActionLabel = isResending
    ? VERIFY_EMAIL_RESEND_LOADING_LABEL
    : resendCooldownSeconds > 0
      ? `Resend in ${resendCooldownSeconds}s`
      : VERIFY_EMAIL_RESEND_ACTION_LABEL;
  const isResendActionDisabled =
    isSetupRecovery ||
    isVerifying ||
    isResending ||
    fetchStatus === 'fetching' ||
    resendCooldownSeconds > 0;
  const isCodeInputDisabled = isVerifying || isResending;

  const focusVerificationCodeInput = () => {
    if (isCodeInputDisabled) {
      return;
    }

    verificationCodeInputRef.current?.focus();
  };

  return (
    <KeyboardAvoidingView behavior="padding" className="flex-1 bg-dark-background">
      <Pressable
        accessibilityLabel="Back to account creation prompt"
        accessibilityRole="button"
        className="absolute left-5 z-10 h-11 w-11 items-center justify-center"
        onPress={() => {
          clearPendingAuthFlow();
          router.replace('/create-account');
        }}
        style={{ top: insets.top + 12 }}>
        <Text className="font-body text-h3 text-white">X</Text>
      </Pressable>

      <ScrollView
        className="flex-1"
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={{
          flexGrow: 1,
          justifyContent: 'center',
          paddingBottom: insets.bottom + 24,
          paddingHorizontal: 20,
          paddingTop: insets.top + 72,
        }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}>
        <View className="w-full max-w-md gap-6 self-center">
          <View className="gap-4">
            <Text className="text-center font-display text-h1 text-dark-text-primary">
              Check your email
            </Text>
            <Text className="text-center font-body text-body text-dark-text-secondary">
              Enter the 6-digit code we sent to {pendingAuthFlow.emailAddress}.
            </Text>
          </View>

          <View className="gap-6 rounded-3xl border border-dark-border bg-dark-surface p-5">
            <View>
              <Pressable
                accessibilityLabel="Verification code entry"
                accessibilityRole="button"
                disabled={isCodeInputDisabled}
                onPress={focusVerificationCodeInput}
                testID="verification-code-entry">
                <View className="flex-row justify-between gap-2">
                  {Array.from({ length: VERIFY_EMAIL_CODE_LENGTH }).map((_, index) => {
                    const digit = code[index] ?? '';

                    return (
                      <View
                        key={index}
                        testID="verification-code-box"
                        className="h-14 flex-1 items-center justify-center rounded-2xl border border-dark-border bg-dark-background">
                        <Text className="font-display text-h2 text-dark-text-primary">{digit}</Text>
                      </View>
                    );
                  })}
                </View>
              </Pressable>

              <TextInput
                ref={verificationCodeInputRef}
                accessibilityLabel="Verification code"
                autoCapitalize="none"
                autoComplete="one-time-code"
                autoCorrect={false}
                className="absolute h-px w-px opacity-0"
                editable={!isCodeInputDisabled}
                keyboardType="number-pad"
                onChangeText={(text) => {
                  setCode(normalizeVerificationCode(text));
                  setErrorMessage(null);
                }}
                placeholder="Verification code"
                placeholderTextColor="#8A90A2"
                secureTextEntry={false}
                textContentType="oneTimeCode"
                value={code}
              />
            </View>

            <Pressable
              accessibilityRole="button"
              className="items-center rounded-2xl bg-brand-primary px-5 py-3"
              disabled={isPrimaryActionDisabled}
              onPress={handlePrimaryAction}
              style={({ pressed }) => ({
                opacity: isPrimaryActionDisabled ? 0.65 : pressed ? 0.92 : 1,
              })}>
              <Text className="font-body-semibold text-body text-white">{primaryActionLabel}</Text>
            </Pressable>

            <Pressable
              accessibilityRole="button"
              className="items-center px-5 py-2"
              disabled={isResendActionDisabled}
              onPress={handleResendCode}
              style={({ pressed }) => ({
                opacity: isResendActionDisabled ? 0.65 : pressed ? 0.8 : 1,
              })}>
              <Text className="font-body-semibold text-body-sm text-dark-text-secondary">
                {resendActionLabel}
              </Text>
            </Pressable>

            {errorMessage ? (
              <Text selectable className="font-body text-body-sm text-red-500">
                {errorMessage}
              </Text>
            ) : null}
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
