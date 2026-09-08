# Why SAML Signing Fails with `AddDeveloperSigningCredential()`

## The root cause: SAML requires an X.509 certificate

SAML signing in Duende IdentityServer **requires an X.509 certificate** — not a bare/raw asymmetric key. This is different from OIDC/JWT signing, which is happy with a raw RSA key. `AddDeveloperSigningCredential()` produces a **raw RSA key**, and that's exactly why your SAML signing breaks.

## Why Automatic Key Management works but `AddDeveloperSigningCredential()` doesn't

Duende bridges the "raw key vs. X.509" gap only in one direction:

- **Automatic Key Management (RSA)**: the auto-generated RSA keys are **automatically wrapped into a self-signed X.509 container** for you. So if you let IdentityServer manage keys, SAML signing works out of the box — and you do **not** need `UseX509Certificate` merely to turn on SAML.
- **Manually registered raw RSA keys — including `AddDeveloperSigningCredential()`**: these **cannot** be auto-wrapped into an X.509 container. There's no certificate for SAML to use, so signing fails.

## The fix: register a real X.509 certificate with a private key

For SAML (in dev or prod), register an X.509 certificate that has a **private key**, instead of `AddDeveloperSigningCredential()`:

```csharp
using System.Security.Cryptography.X509Certificates;

var cert = X509CertificateLoader.LoadPkcs12FromFile(
    "saml-signing.pfx", "password"); // must include the private key

builder.Services.AddIdentityServer()
    .AddSigningCredential(cert)   // X.509 cert WITH private key
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

For local development you can generate a self-signed cert (e.g., with `dotnet dev-certs`, PowerShell's `New-SelfSignedCertificate`, or OpenSSL) and load it as above. The important part is that it carries a private key so it can actually sign.

Alternatively, just rely on **Automatic Key Management** (don't call `AddDeveloperSigningCredential()` at all) and let IdentityServer generate and X.509-wrap the RSA keys for you.

## Two important caveats

1. **`UseX509Certificate` is not needed just to enable SAML.** With Automatic Key Management RSA keys, wrapping happens automatically. You only reach for an explicit X.509 cert when you're supplying keys manually (as here).
2. **`UseX509Certificate` is not supported for EC keys.** The default SAML signing service is **RSA-only**. If you need Elliptic Curve keys (or HSM/Key Vault EC scenarios), you must implement a custom **`ISamlSigningService`** — `UseX509Certificate` won't cover EC.

## Summary

- SAML needs an **X.509 certificate**; raw RSA keys won't do.
- **Automatic Key Management RSA** → auto-wrapped into a self-signed X.509 container (works).
- **`AddDeveloperSigningCredential()` (raw RSA)** → cannot be wrapped → **use an X.509 cert with a private key** instead.
- `UseX509Certificate` isn't required just to enable SAML and **doesn't support EC** keys (custom `ISamlSigningService` needed for EC).
