# iOS Export Compliance Design

## Goal

Prevent future Signa uploads from showing **Missing Compliance** when the app
uses no non-exempt encryption.

## Decision

Add the Boolean `ITSAppUsesNonExemptEncryption` key with a value of `false` to
`app/ios/Runner/Info.plist`.

Signa uses standard platform and authentication mechanisms: HTTPS, Apple secure
storage, SHA-256/PKCE, and Ed25519 signature verification. It does not implement
proprietary encryption or a custom cipher. The declaration therefore states
that the app uses no non-exempt encryption; it does not claim that the app uses
no security or cryptographic primitives.

## Scope

- Add the export-compliance Boolean to the iOS application plist.
- Add a release-configuration regression test that parses the plist and asserts
  the Boolean is present and false.
- Verify the plist, Flutter tests, static analysis, and an unsigned iOS release
  build suitable for later signing/archive work.
- Bump the iOS build number before uploading a replacement for Build 3.

Existing App Store Connect builds cannot be modified. Build 3 must have its
compliance question completed manually or be superseded by the new build.

## Failure Handling

If a future Signa release adds proprietary/non-exempt encryption, the declaration
must be reassessed before upload. The release test intentionally makes the current
decision visible rather than allowing the key to disappear silently.

## Acceptance Criteria

1. The built iOS app contains `ITSAppUsesNonExemptEncryption = false`.
2. The release configuration test fails if the key is absent or true.
3. All Flutter tests and static analysis pass.
4. The next upload uses a new build number.
