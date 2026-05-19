# Repository Guidelines

For project information refer to the `docs/SPEC.md` file.

## Project Structure & Module Organization

This is an Expo Router React Native app. Route files live in `app/`; grouped tab routes are under `app/(tabs)/`, shared layout is in `app/_layout.tsx`, and modal/not-found routes are top-level files. Reusable UI components live in `components/`, and any component that is not a screen should live outside of `app/` in `components/`. Zustand state modules live in `store/`. Supabase and integration helpers belong in `utils/`. Static icons and splash assets are in `assets/`. Styling uses `global.css`, `tailwind.config.js`, NativeWind, and component `className` strings.

## Build, Test, and Development Commands

- `npm start`: start the Expo development server.
- `npm run ios`: start Expo and open the iOS simulator.
- `npm run android`: start Expo and open an Android target.
- `npm run web`: run the app with Expo for web.
- `npm run prebuild`: generate native `ios/` and `android/` projects when needed.
- `npm run lint`: run ESLint and check Prettier formatting.
- `npm run format`: apply ESLint fixes and Prettier formatting.
- `npm test`: run the Jest test suite.

Use `npm install` to restore dependencies from `package-lock.json`.

## Coding Style & Naming Conventions

Use TypeScript with strict checking enabled. Prefer functional React components. Keep route-specific code in `app/`, and extract reusable UI to `components/`. Component files use PascalCase, for example `HeaderButton.tsx`; utility and store modules use lower-case descriptive names, for example `supabase.ts`. Use the `@/*` path alias for clear root-relative imports.

Prettier controls formatting: 2-space indentation, single quotes, ES5 trailing commas, 100-character print width, and Tailwind class sorting. Run `npm run format` before submitting changes.

## Testing Guidelines

Jest, `react-test-renderer`, and `@testing-library/react-native` are installed. When implementing or changing a screen, feature, or store behavior, add or update tests in the same change. Colocate tests near the code in a folder named `__tests__` with names like `Button.test.tsx` or `assessment-store.test.ts`. Prefer React Native Testing Library for user-facing behavior. Use `npm test` as the standard local test command.

## Commit & Pull Request Guidelines

Git history currently only contains `Initial commit`, so there is no established project-specific convention. Use concise, imperative commit subjects such as `Add tab settings screen` or `Fix Supabase client initialization`.

Pull requests should include a short summary, affected screens or modules, local verification steps, and screenshots for visible UI changes. Link issues when available and call out configuration, Supabase, or native prebuild implications.

## Security & Configuration Tips

Do not commit secrets, Supabase service keys, or local environment files. Keep public Expo configuration in `app.json`; put sensitive runtime configuration in ignored environment files or deployment secrets.

## Available Skills

Invoke these skills when a task matches the trigger described below.

| Skill                        | Invoke when                                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| `building-native-ui`         | Building polished Expo Router native UI, navigation, styling, or app screens.       |
| `javascript-typescript-jest` | Writing or fixing JavaScript/TypeScript Jest tests and mocks.                       |
| `maestro`                    | Writing, debugging, or running Maestro UI automation flows.                         |
| `native-data-fetching`       | Implementing or debugging fetches, API calls, caching, or offline data behavior.    |
| `react-hook-form-zod`        | Building or reviewing React Hook Form flows with Zod validation.                    |
| `react-native-testing`       | Writing or fixing React Native Testing Library component tests.                     |
| `tdd`                        | Using a red-green-refactor loop for features, fixes, or integration tests.          |
| `vercel-react-native-skills` | Improving React Native or Expo performance, components, animations, or native APIs. |

## Rules

- NEVER search or grep inside the `node_modules` directory.
- If you need to check a dependency, look at `package.json` or `package-lock.json` instead.
- Do not attempt to edit any files within `node_modules`.
