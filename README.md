# Native authentication for iOS and macOS with Microsoft Entra External ID

This SwiftUI sample demonstrates native sign-up, sign-in, password reset, session restoration,
sign-out, browser fallback, and optional protected API access with the Microsoft Authentication
Library (MSAL).

> [!IMPORTANT]
> Native Auth v2 is experimental in MSAL 2.16.0 and its public API documentation says not to use it
> in production applications. Debug builds expose the v2 toggle for evaluation; Release builds
> default to the supported v1 flow. Validate service availability and all required journeys in your
> tenant before considering an integration production-ready.

## Project contents

| Path | Purpose |
| --- | --- |
| `NativeAuthSampleApp.xcodeproj` | iOS/macOS app and exact MSAL package dependency |
| `NativeAuthSampleApp/Configuration.swift` | Tenant, optional API, and test-slice settings |
| `NativeAuthSampleApp/SignIn` | Shared UI plus v1 and v2 flow delegates |
| `NativeAuthSampleApp/ProtectedAPIClient.swift` | HTTPS-only ****** boundary |
| `NativeAuthSampleAppTests` | Mocked configuration and HTTP boundary tests |
| `ci/github-actions-ci.yml` | Ready-to-install clean resolve, test, and simulator-build workflow |
| `auto-config.json` | Microsoft sample auto-configuration metadata |

## Prerequisites

- Xcode 16.4 or newer
- iOS 17 or macOS 14 deployment target
- A Microsoft Entra External ID tenant
- A native-auth-enabled public client registration and an associated sign-up/sign-in user flow

Follow the External ID guide to [register the app, enable native authentication, configure a user
flow, and add test users](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app).
Register the redirect URI `msauth.<bundle-id>://auth`, where `<bundle-id>` exactly matches
`PRODUCT_BUNDLE_IDENTIFIER`. The project already declares that URL scheme and the MSAL keychain
groups:

- iOS: `$(AppIdentifierPrefix)com.microsoft.adalcache`
- macOS: `$(AppIdentifierPrefix)com.microsoft.identity.universalstorage`

Select your own development team for device signing. Do not commit tenant credentials, user
passwords, tokens, or signing identities.

## Dependency strategy

The Xcode project uses the public MSAL Swift package at **exact version 2.16.0**. This is the first
verified release used by this branch that publishes the v2 sign-in/sign-up/reset symbols exercised
by the sample. Open the project and Xcode resolves the package automatically, or resolve it from a
clean checkout:

```bash
xcodebuild -resolvePackageDependencies \
  -project NativeAuthSampleApp.xcodeproj \
  -scheme NativeAuthSampleApp
```

The upstream `dev` branch's `Package.swift` was checked at commit
`de46a5b76a4a3540c9998a76ee21809a39e10f76`: it declares a binary target whose URL and checksum are
the released 2.16.0 `MSAL.zip`. Selecting the `dev` branch in Swift Package Manager therefore tests
that released binary, **not** current dev source.

### Opt in to current MSAL dev source

Use this only in an experimental branch or local checkout:

1. Remove the MSAL Swift package product from the app target.
2. Clone upstream source outside this repository and initialize its submodules:

   ```bash
   git clone --branch dev --recurse-submodules \
     https://github.com/AzureAD/microsoft-authentication-library-for-objc.git
   cd microsoft-authentication-library-for-objc
   git rev-parse HEAD
   ```

3. Add `MSAL/MSAL.xcodeproj` to a local workspace containing this sample, link the platform's
   `MSAL.framework` product, and build it as an implicit dependency.
4. Record the tested commit SHA in the resulting PR evidence. Re-run the unit tests and both
   supported platform builds.

Do not commit a machine-specific checkout path. Revert the workspace-only experiment to return to
the pinned package. This workflow is intentionally explicit because upstream SPM does not build dev
source.

## Configure the sample

Edit `NativeAuthSampleApp/Configuration.swift`:

```swift
static let clientId = "<application-client-id>"
static let tenantSubdomain = "<tenant-subdomain>"
```

Use only the subdomain portion (for example, `contoso`, not a full URL). Placeholder, malformed
client ID, and malformed subdomain values produce an actionable message instead of attempting
authentication.

Production routing is the default:

```swift
static let testSliceDataCenter: String? = nil
```

Test slices are for authorized internal diagnostics only. Setting this value opts every native and
browser request into that test route; never ship a slice value.

## Authentication scenarios

The common screen supports:

- Password or email one-time-passcode sign-in
- Sign-up with required attributes
- Self-service password reset
- MFA and just-in-time strong authentication registration
- Cached native-auth session restoration
- Browser fallback and configured social identity-provider hints
- Sign-out from native or browser-backed state

V1 remains the supported default for Release builds. V2 is enabled by default only in Debug builds
and can be selected with **Use V2 API (preview)**. V2 behavior depends on both MSAL and tenant
service rollout. MSAL 2.16.0 marks all v2 APIs experimental; do not infer general availability from
a successful compile. Browser fallback also requires the corresponding identity provider to be
configured in the tenant user flow.

## Optional protected API

Basic authentication works when the API settings remain empty. To enable the button, register or
expose an API, grant the public client delegated permission, then set:

```swift
static let protectedAPIEndpoint = "https://api.example.com/me"
static let protectedAPIScopes = ["api://<api-client-id>/access_as_user"]
```

The endpoint must use HTTPS and at least one scope is required. The app requests a token for those
scopes and sends it only in the `Authorization` header. Redirects are blocked so a credential
cannot be forwarded to another URL. Network and non-2xx failures are shown without displaying
error response bodies.

If MSAL reports that interaction is required (including a claims requirement), use browser sign-in
to satisfy it and retry. The verified native token API accepts scopes and an optional
`MSALClaimsRequest`, but MSAL 2.16.0 does not expose a native interactive continuation from
`RetrieveAccessTokenError`; the sample does not attempt to parse or replay arbitrary
`WWW-Authenticate` claims.

## Run and validate

1. Open `NativeAuthSampleApp.xcodeproj`.
2. Select the `NativeAuthSampleApp` scheme and an iOS 17+ simulator/device or macOS 14+ destination.
3. Configure signing when running on a device.
4. Build and run.

Local boundary tests:

```bash
swift test
```

Unsigned simulator build:

```bash
xcodebuild build \
  -project NativeAuthSampleApp.xcodeproj \
  -scheme NativeAuthSampleApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

`ci/github-actions-ci.yml` contains the hosted macOS workflow for dependency resolution, boundary
tests, and that build. This task's GitHub App was not permitted to create files under
`.github/workflows`, so a maintainer must review and copy it there before hosted CI can run.
Workflow execution may also require Actions approval and available hosted-runner quota.

Tenant-dependent acceptance tests cannot run in CI without live credentials. Manually verify v1
and v2 password/OTP sign-in, sign-up attributes, reset password, MFA/JIT registration, browser and
social fallback, relaunch restoration, cancellation, protected API success/401/network failure,
and sign-out followed by relaunch.

## Troubleshooting

- **Configure clientId and tenantSubdomain**: replace both placeholders with values from the same
  app registration and tenant.
- **Redirect mismatch**: ensure the registered URI and `PRODUCT_BUNDLE_IDENTIFIER` produce the same
  `msauth.<bundle-id>://auth` value.
- **Keychain error**: enable the required keychain-sharing group for the selected signing team.
- **Native flow requires browser**: confirm the user flow supports the selected method, then use
  browser sign-in.
- **API 401/403**: verify the configured delegated scope, consent, API audience, and tenant policy.
- **V2 callback or service error**: reproduce with pinned MSAL first, capture a non-PII correlation
  ID if available, and check the MSAL release notes/service rollout before trying dev source.

## Contributing and support

See [CONTRIBUTING.md](CONTRIBUTING.md). Search existing
[issues](https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample/issues) before
opening a new report. Never include tokens, passwords, or personally identifiable information.
