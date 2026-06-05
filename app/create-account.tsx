import { useAuth, useSignUp } from '@clerk/expo';
import { useRouter } from 'expo-router';
import {
  Alert,
  KeyboardAvoidingView,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { CREATE_ACCOUNT_UNAVAILABLE_ALERTS } from '@/constants/create-account-actions';
import type { ClerkEmailPasswordSignUp } from '@/types/clerk-sign-up-flow';
import type { CreateAccountActionId } from '@/types/create-account-actions';
import { dismissCreateAccountPrompt } from '@/utils/create-account-dismissal';
import { useCreateAccountAuth } from '@/utils/use-create-account-auth';

const showUnavailableAlert = (actionId: CreateAccountActionId) => {
  const alertCopy = CREATE_ACCOUNT_UNAVAILABLE_ALERTS[actionId];
  Alert.alert(alertCopy.title, alertCopy.message);
};

export default function CreateAccountScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { getToken } = useAuth();
  const { signUp, fetchStatus } = useSignUp();
  const {
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
  } = useCreateAccountAuth({
    signUp: signUp as ClerkEmailPasswordSignUp | null | undefined,
    fetchStatus,
    getToken,
    router,
  });

  return (
    <KeyboardAvoidingView behavior="padding" className="flex-1 bg-dark-background">
      <Pressable
        accessibilityLabel="Close account creation prompt"
        accessibilityRole="button"
        className="absolute left-5 z-10 h-11 w-11 items-center justify-center"
        onPress={() => dismissCreateAccountPrompt(router)}
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
          <View className="gap-6">
            <Text className="text-center font-display text-h1 text-dark-text-primary">
              Create an account to save your progress
            </Text>

            <Pressable
              accessibilityRole="button"
              className="flex-row items-center justify-center gap-2 rounded-2xl bg-white px-5 py-4"
              onPress={() => showUnavailableAlert('apple')}>
              <View
                accessibilityLabel="Apple logo"
                accessibilityRole="image"
                accessible
                testID="create-account-apple-logo">
                <Text className="font-body-semibold text-body text-black"></Text>
              </View>
              <Text className="font-body-semibold text-body text-black">Continue with Apple</Text>
            </Pressable>
          </View>

          <View className="flex-row items-center gap-3">
            <View className="h-px flex-1 bg-dark-border" />
            <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
              OR
            </Text>
            <View className="h-px flex-1 bg-dark-border" />
          </View>

          <View className="gap-6 rounded-3xl border border-dark-border bg-dark-surface p-5">
            <View className="gap-3">
              <View className="gap-2">
                <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                  Email address
                </Text>
                <TextInput
                  accessibilityLabel="Email address"
                  autoCapitalize="none"
                  autoComplete="email"
                  className="rounded-2xl border border-dark-border bg-dark-background px-4 py-3 font-body text-body text-dark-text-primary"
                  keyboardType="email-address"
                  onChangeText={(text) => {
                    setEmail(text);
                    setEmailError(null);
                    setFormError(null);
                  }}
                  placeholder="Email address"
                  placeholderTextColor="#8A90A2"
                  textContentType="emailAddress"
                  value={email}
                />
                {emailError ? (
                  <Text selectable className="text-brand-error font-body text-body-sm">
                    {emailError}
                  </Text>
                ) : null}
              </View>
              <View className="gap-2">
                <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                  Password
                </Text>
                <TextInput
                  accessibilityLabel="Password"
                  autoCapitalize="none"
                  autoComplete="new-password"
                  className="rounded-2xl border border-dark-border bg-dark-background px-4 py-3 font-body text-body text-dark-text-primary"
                  onChangeText={(text) => {
                    setPassword(text);
                    setPasswordError(null);
                    setFormError(null);
                  }}
                  placeholder="Password"
                  placeholderTextColor="#8A90A2"
                  secureTextEntry
                  textContentType="newPassword"
                  value={password}
                />
                {passwordError ? (
                  <Text selectable className="text-brand-error font-body text-body-sm">
                    {passwordError}
                  </Text>
                ) : null}
              </View>
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

            {formError ? (
              <Text selectable className="text-brand-error font-body text-body-sm">
                {formError}
              </Text>
            ) : null}

            <View nativeID="clerk-captcha" testID="clerk-captcha" />
          </View>

          <Pressable
            accessibilityLabel="Already have an account? Sign in."
            accessibilityRole="button"
            className="items-center px-2 py-1"
            onPress={() => showUnavailableAlert('sign-in')}>
            <Text className="text-center font-body text-body text-dark-text-secondary">
              Already have an account?{' '}
              <Text className="font-body-semibold text-dark-text-primary">Sign in.</Text>
            </Text>
          </Pressable>

          <Text className="mt-7 text-center font-body text-body-sm text-dark-text-secondary">
            Free to start. No payment required.
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
