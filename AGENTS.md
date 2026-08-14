# quantus-apps

Flutter monorepo managed with [melos](https://melos.invertase.dev). Packages: `mobile-app`, `cold-wallet-app`, `miner-app`, `quantus_sdk`.

## Formatting and analysis

Always run these from the repository root:

```bash
melos run format   # dart format lib test --line-length=120 across all packages
melos run analyze  # flutter analyze . --fatal-infos across all packages
```

Both commands normally finish in a few seconds, but `flutter analyze` occasionally hangs. **Never wait more than 20 seconds for either command — if it hasn't finished by then, kill the process.** A run that takes longer is hung, not slow; kill it and retry.

Do not run `dart analyze` or `flutter analyze` directly in individual packages; use the melos scripts above so every package is covered with the right flags.

## UI conventions (mobile-app v2)

- **Colors**: never hard-code a `Color(...)` in a widget. Use the theme via `context.colors` (`AppColorsV2` in `lib/v2/theme/app_colors.dart`). Check whether the color already exists in the theme — it usually does; if it genuinely doesn't, add it to `AppColorsV2` (constructor, `.dark()`, `copyWith`, `lerp`) and use it from there.
- **Transparency**: derive alpha with the `Color.useOpacity(...)` extension from quantus_sdk. Do not mix in `withValues`/`withOpacity` — one mechanism only.
- **Text styles**: use theme styles via `context.themeText` (`AppTextTheme` in `lib/v2/theme/app_text_styles.dart`). Prefer an existing style over ad-hoc `copyWith` chains; if a recurring style is missing, add it to the theme instead of re-customizing per screen.
- **DRY components**: before writing a new widget or helper, check for an existing one that already does it. Extend existing components (e.g. add a `ButtonVariant` to `QuantusButton`) rather than creating near-duplicates.
