---
name: react-hook-form-zod
description: React Native form handling with React Hook Form, @hookform/resolvers, and Zod. Use when building, refactoring, or reviewing forms, validation, submit and reset flows, controlled inputs, field arrays, or cross-field rules.
---

# React Hook Form Zod

## Overview

Use this skill for form work in this Expo app. Treat the Zod schema as the source of truth, let React Hook Form own form state, and keep React Native input wiring explicit.

## Core Rules

- Define one Zod schema per form and infer types from it.
- Pass `zodResolver(schema)` to `useForm`.
- Provide complete `defaultValues` for every field. Use `""`, `null`, `false`, or `[]` instead of `undefined`.
- Use `Controller` or `useController` for React Native inputs such as `TextInput`, `Switch`, pickers, and custom components.
- Destructure the `formState` values you actually read so subscriptions update correctly.
- Use `reset` to load existing records or clear a form after save.
- Use `useFieldArray` for repeatable groups.
- Keep validation in Zod unless you need a small UI-only rule that does not belong in the schema.

## Best-Practice Reference

See [references/forms.md](references/forms.md) for the detailed patterns, examples, and edge cases.
