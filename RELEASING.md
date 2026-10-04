# Releasing

Push a version tag; the [Release workflow](.github/workflows/release.yml) runs the tests, builds a universal app, packages `SpaceSnap.dmg` and `SpaceSnap.zip`, and publishes a GitHub release:

```sh
git tag v1.0.1
git push origin v1.0.1
```

Without signing secrets the release is ad-hoc signed. To ship a Developer ID signed and notarized release, add these repository secrets:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | `base64 -i DeveloperID.p12` of your "Developer ID Application" certificate with its private key |
| `DEVELOPER_ID_P12_PASSWORD` | Password of that `.p12` |
| `APPLE_ID` | Apple ID email of the developer account |
| `APPLE_TEAM_ID` | Team ID |
| `APPLE_APP_PASSWORD` | App-specific password from [account.apple.com](https://account.apple.com) |

Locally the same works with `SIGN_IDENTITY="Developer ID Application: …"` and either those `APPLE_*` variables or `NOTARY_KEYCHAIN_PROFILE` (created with `xcrun notarytool store-credentials`):

```sh
SIGN_IDENTITY="Developer ID Application: …" VERSION=1.0.1 ./scripts/bundle.sh
NOTARY_KEYCHAIN_PROFILE=spacesnap SIGN_IDENTITY="Developer ID Application: …" ./scripts/package.sh
```
