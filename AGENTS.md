# Repository Guidelines

For project information refer to the `docs/SPEC.md` file. ALWAYS check the `docs/CONTEXT.md` for domain language.

## Project Structure & Module Organization

This is an Expo Router React Native app. Route files live in `app/`; grouped tab routes are under `app/(tabs)/`, shared layout is in `app/_layout.tsx`, and modal/not-found routes are top-level files. Reusable UI components live in `components/`. Zustand state is in `store/store.ts`. Supabase and integration helpers belong in `utils/`. Static icons and splash assets are in `assets/`. Styling uses `global.css`, `tailwind.config.js`, NativeWind, and component `className` strings.

## Build, Test, and Development Commands

- `npm start`: start the Expo development server.
- `npm run ios`: start Expo and open the iOS simulator.
- `npm run android`: start Expo and open an Android target.
- `npm run web`: run the app with Expo for web.
- `npm run prebuild`: generate native `ios/` and `android/` projects when needed.
- `npm run lint`: run ESLint and check Prettier formatting.
- `npm run format`: apply ESLint fixes and Prettier formatting.

Use `npm install` to restore dependencies from `package-lock.json`.

## Coding Style & Naming Conventions

Use TypeScript with strict checking enabled. Prefer functional React components. Keep route-specific code in `app/`, and extract reusable UI to `components/`. Component files use PascalCase, for example `HeaderButton.tsx`; utility and store modules use lower-case descriptive names, for example `supabase.ts`. Use the `@/*` path alias for clear root-relative imports.

Prettier controls formatting: 2-space indentation, single quotes, ES5 trailing commas, 100-character print width, and Tailwind class sorting. Run `npm run format` before submitting changes.

## Testing Guidelines

Jest, `react-test-renderer`, and `@testing-library/react-native` are installed, but no test script or test files are currently defined. When adding tests, colocate them near the code under test with names like `Button.test.tsx` or `store.test.ts`. Prefer React Native Testing Library for user-facing behavior. Add an `npm test` script before relying on automated tests in CI or pull requests.

## Commit & Pull Request Guidelines

Git history currently only contains `Initial commit`, so there is no established project-specific convention. Use concise, imperative commit subjects such as `Add tab settings screen` or `Fix Supabase client initialization`.

Pull requests should include a short summary, affected screens or modules, local verification steps, and screenshots for visible UI changes. Link issues when available and call out configuration, Supabase, or native prebuild implications.

## Security & Configuration Tips

Do not commit secrets, Supabase service keys, or local environment files. Keep public Expo configuration in `app.json`; put sensitive runtime configuration in ignored environment files or deployment secrets.
