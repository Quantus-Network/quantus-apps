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
