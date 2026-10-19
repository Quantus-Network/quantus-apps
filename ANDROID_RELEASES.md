# Android releases

This page explains how the wallet APKs on GitHub Releases are built and signed. It also shows how to check that an APK came from this repository and from a specific commit.

## What ties a release to the code

- **Signed builds come from `main` only.** The `Create Wallet Android Build` workflow refuses to sign or publish a release build from any other ref. Debug builds still work from any branch.
- **Pinned inputs.** The build uses the Flutter version in `.fvmrc`, actions pinned to commit SHAs, and `--enforce-lockfile` for every Dart package. No build caches are used. The build fails if it changes any tracked file, so the APK matches the committed sources and lockfiles. The lockfiles only record a minimum Flutter version, so `.fvmrc` names the exact one. Change it together with the lockfiles: `--enforce-lockfile` fails if the Flutter SDK pins differ from them.
- **Signing keys stay out of the build.** The APK is compiled unsigned. A separate job signs it with `apksigner`. That job runs no project build code, and the keys live only in the `android-release` environment.
- **Checked before publishing.** The signing job runs `scripts/verify_android_apk.sh`. It checks that the signer certificate matches `android/upload_certificate.pem` in the app folder. It also checks the package name and version against `build.gradle` and `pubspec.yaml`.
- **Build provenance.** GitHub signs a SLSA provenance attestation for the APK through Sigstore. The attestation records the repository, the workflow, the commit and the run.
- **Release assets.** Each release has the APK, `SHA256SUMS`, `build-info.txt` with the toolchain versions, and the attestation bundle (`*.sigstore.json`).
- **Tag and release.** The workflow creates the tag at the built commit and publishes from a draft. With immutable releases turned on, the tag and assets cannot change after publishing.

## Signing certificates

Android only installs an update when it is signed with the same certificate as the installed app.

| App | Package | Certificate SHA-256 |
|-----|---------|---------------------|
| Quantus Wallet | `com.quantus.wallet` | `a5be802e734e26ee454877e2aea903aef9110a06354607102f6e97461b3fcd5e` |
| Quantus Cold Wallet | `com.quantus.coldwallet` | `07fa0524105c0a13bde75f7ed55f62b85cd13e06660835d881dc451d0f6cb25c` |

The certificates are committed as `mobile-app/android/upload_certificate.pem` and `cold-wallet-app/android/upload_certificate.pem`. A copy installed from Google Play under Play App Signing has Google's certificate instead. It cannot be updated with a GitHub APK, and a GitHub install cannot be updated from Play.

## Verify a release

From a clone of this repository, with `gh` signed in and Android build-tools 35 or newer on `PATH`:

```sh
scripts/verify_android_release.sh wallet-v1.7.4+158
```

The script checks five things:

1. The tag resolves to a commit and the release is immutable.
2. The assets match `SHA256SUMS`.
3. The provenance attestation was made by `build_wallet_apk.yml` on `main` for that exact commit.
4. GitHub's release attestation covers the APK.
5. The APK's signer, package name and version match the sources at that commit.

To check by hand:

```sh
sha256sum -c SHA256SUMS
gh attestation verify <apk> --repo Quantus-Network/quantus-apps \
  --signer-workflow Quantus-Network/quantus-apps/.github/workflows/build_wallet_apk.yml \
  --source-ref refs/heads/main --source-digest <commit from the release notes>
apksigner verify --print-certs <apk>
```

To verify without GitHub's attestation API, add `--bundle <apk>.sigstore.json` to the `gh attestation verify` command.

## Repository settings

The workflow cannot enforce these settings itself. An admin sets them once.

```sh
R=repos/Quantus-Network/quantus-apps

# 1. Only main can use the signing environment, and a reviewer approves each signing run.
gh api -X PUT $R/environments/android-release --input - <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true},
 "reviewers": [{"type": "User", "id": <user id from: gh api users/LOGIN --jq .id>}]}
JSON
gh api -X POST $R/environments/android-release/deployment-branch-policies -f name=main -f type=branch

# 2. Move the signing secrets into the environment, then delete the repository-wide copies.
#    Secret values cannot be read back, so set them again from the offline keystore backup.
for s in ANDROID_KEYSTORE_BASE64 ANDROID_STORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD \
         COLD_ANDROID_KEYSTORE_BASE64 COLD_ANDROID_STORE_PASSWORD COLD_ANDROID_KEY_ALIAS COLD_ANDROID_KEY_PASSWORD; do
  gh secret set "$s" --env android-release --repo Quantus-Network/quantus-apps
done
# After a signed test build succeeds:
#   for s in ...same list...; do gh secret delete "$s" --repo Quantus-Network/quantus-apps; done

# 3. Make published releases immutable.
gh api -X PUT $R/immutable-releases

# 4. Stop release tags from being moved or deleted.
gh api -X POST $R/rulesets --input - <<'JSON'
{"name": "Release tags", "target": "tag", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["refs/tags/wallet-v*", "refs/tags/cold-wallet-v*"], "exclude": []}},
 "rules": [{"type": "deletion"}, {"type": "update"}]}
JSON
```

## Reproducing a build

Builds are not yet checked for byte-for-byte reproducibility. `build-info.txt` records what a rebuild needs: the Flutter revision, the Rust nightly, the JDK and the runner image. Known gaps:

- `quantus_sdk/rust/cargokit.yaml` builds with whatever `nightly` is current, so the Rust compiler changes between builds.
- cargokit resolves the Dart dependencies of its build tool without a lockfile.
- The mobile APK bundles `mobile-app/.env` and `google-services.json`, which come from repository secrets. The `.env` file ships inside the APK as `assets/flutter_assets/.env`.
