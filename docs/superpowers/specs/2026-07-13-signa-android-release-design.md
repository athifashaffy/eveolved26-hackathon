# Signa Android Release Design

## Goal

Produce a Play Console-ready, signed Android App Bundle for Signa and publish the release safely through GitHub.

## Release identity

- Android application ID and Kotlin namespace: `com.thealphanova.signa`.
- App version: `1.0.1+8`, producing Android `versionName` 1.0.1 and `versionCode` 8.
- Upload-key alias: `alias_name`.
- The user-supplied password is used for both the keystore and key entry.
- The generated upload key is valid for 10,000 days and uses RSA 2048 with SHA-256.

## Signing and secret handling

The repository is public. The raw JKS and `android/key.properties` must remain ignored and uncommitted because possession of the upload key would allow unauthorized release uploads. The local keystore will be created under `app/android/` and a local ignored `key.properties` will point Gradle to it.

GitHub storage will use encrypted Actions secrets rather than Git history:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded JKS
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: `alias_name`
- `ANDROID_KEY_PASSWORD`: key password

The public GitHub Release contains the signed `.aab` and a SHA-256 checksum, never the raw keystore or plaintext credentials.

## Source changes

Update the Gradle namespace/application ID and move the Kotlin launcher file to the matching package directory. Update release tests and store metadata to protect the new identity, build number, alias template, and secret exclusions. No application behavior or health-data permissions change.

## Build and verification

Run the Flutter test suite and analyzer, then build with `flutter build appbundle --release`. Verify the output with Android bundle tooling and `keytool`: package ID, version code/name, signing certificate, alias, and SHA-256. Confirm Git does not track the JKS or `key.properties` before committing.

## GitHub publication

Commit the source/configuration changes to the current feature branch and push it normally. Create tag/release `signa-android-v1.0.1-build8`, attach `Signa-1.0.1-build8.aab` and its checksum, and add the signing values as encrypted GitHub repository secrets. If GitHub authentication cannot be recovered from an existing signed-in session, finish the local signed artifact and report that single external-authentication blocker without exposing secrets.
