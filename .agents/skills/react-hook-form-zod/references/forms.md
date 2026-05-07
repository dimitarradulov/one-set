# React Hook Form + Zod Patterns

## Contents

- [Schema-First Setup](#schema-first-setup)
- [React Native Input Wiring](#react-native-input-wiring)
- [Validation Strategy](#validation-strategy)
- [Submission, Reset, and State](#submission-reset-and-state)
- [Reusable Fields and Arrays](#reusable-fields-and-arrays)
- [Example](#example)
- [Common Mistakes](#common-mistakes)

## Schema-First Setup

- Treat the Zod schema as the source of truth.
- Derive form types from the schema instead of duplicating interfaces.
- If the schema does not transform values, `z.infer<typeof schema>` is enough.
- If the schema transforms values, keep the input and output types explicit with `z.input` and `z.output`.
- Pass `zodResolver(schema)` to `useForm`.

```tsx
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";

const schema = z.object({
  email: z.string().trim().email("Enter a valid email"),
  password: z.string().min(8, "Use at least 8 characters"),
  rememberMe: z.boolean(),
});

type FormInput = z.input<typeof schema>;
type FormOutput = z.output<typeof schema>;

const form = useForm<FormInput, any, FormOutput>({
  resolver: zodResolver(schema),
  defaultValues: {
    email: "",
    password: "",
    rememberMe: false,
  },
});
```

## React Native Input Wiring

- Use `Controller` for `TextInput`, `Switch`, pickers, and custom inputs.
- Use `useController` when you want to build a reusable field component.
- Wire `TextInput` through `value`, `onChangeText`, and `onBlur`.
- Wire `Switch` through `value` and `onValueChange`.
- Keep cleared values as `""`, `null`, `false`, or `[]`, not `undefined`.
- Prefer `Controller` over manual `setValue` plumbing for visible fields.

```tsx
<Controller
  control={control}
  name="email"
  render={({ field: { value, onChange, onBlur } }) => (
    <TextInput
      value={value}
      onBlur={onBlur}
      onChangeText={onChange}
      keyboardType="email-address"
      autoCapitalize="none"
    />
  )}
/>
```

## Validation Strategy

- Keep field-level rules in the schema unless they are purely UI concerns.
- Use `.refine()` for a single custom rule.
- Use `.superRefine()` when you need cross-field validation or multiple issues.
- Use `safeParse` or `safeParseAsync` at boundaries where you want to handle invalid data without throwing.
- Use transforms carefully. Prefer stable input types in the UI, then normalize at the edge.
- If a form field is a string in the UI but numeric in the payload, keep the input stable and convert through the schema or submit layer.
- Use `criteriaMode: "all"` only when the UI actually needs every issue on a field.

## Submission, Reset, and State

- Start with `mode: "onSubmit"` unless live validation materially improves the experience.
- Destructure the `formState` fields you need. Do not rely on conditional property access from the proxy.
- Use `isSubmitting` to disable the submit action.
- Use `isDirty` for unsaved-change prompts.
- Use `reset` with a full object when loading existing data or after a successful save.
- Use `setError` for server-side validation failures that come back after submit.
- Use `shouldUnregister: true` only when unmounted fields should be removed from submission data.

## Reusable Fields and Arrays

- Use `useController` for shared field components so the screen code stays small.
- Use `useFieldArray` for repeated sections, line items, and other dynamic collections.
- Keep field names and schema paths aligned so validation messages map cleanly to inputs.
- When a field is conditionally hidden, decide explicitly whether its value should persist or disappear on unmount.

## Example

```tsx
const schema = z
  .object({
    password: z.string().min(8, "Use at least 8 characters"),
    confirmPassword: z.string().min(8, "Use at least 8 characters"),
  })
  .superRefine((value, ctx) => {
    if (value.password !== value.confirmPassword) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["confirmPassword"],
        message: "Passwords do not match",
      });
    }
  });
```

## Common Mistakes

- Duplicating the same validation in both Zod and `rules`.
- Leaving out `defaultValues` or using `undefined` as a default.
- Using `formState.foo` conditionally and expecting the UI to subscribe.
- Mixing `Controller` and `register` on the same field.
- Calling `reset` with only part of the form state.
- Storing both raw and parsed copies of the same field state in React state.
