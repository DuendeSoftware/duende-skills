# Why `AddDeveloperSigningCredential()` fails for SAML

SAML signing **requires an X.509 certificate with a private key**. `AddDeveloperSigningCredential()` produces a raw RSA key (persisted as `tempkey.jwk`), and manual/raw RSA keys **cannot be auto-wrapped** into an X.509 container. That's why SAML signing fails, even though OIDC token signing works.

(OIDC and SAML share the same signing credentials.)

## Options

**1. Automatic Key Management (RSA)** — easiest: auto-generated RSA keys are wrapped in a self-signed X.509 container for you, so you don't need `UseX509Certificate` just to enable SAML. Rotation is governed by `PropagationTime`/`RetentionDuration`.

**2. Explicit X.509 certificate with private key** (dev or prod):

```csharp
var cert = X509CertificateLoader.LoadPkcs12FromFile("idp-signing.pfx", password);

builder.Services.AddIdentityServer()
    .AddSigningCredential(cert, "RS256")   // or the UseX509Certificate option in key management
    .AddSaml();
```

For dev, generate a self-signed PFX (openssl / `New-SelfSignedCertificate`). Remove `AddDeveloperSigningCredential()`.

## Other gotchas
- The default SAML signing service is **RSA-only**; EC keys are unsupported — implement a custom `ISamlSigningService`.
- Cloud KMS/remote keys wired through a custom `ITokenCreationService` do **not** cover SAML (SAML reads the signing credential directly and needs a private key). For KMS/HSM/Key Vault, implement `ISamlSigningService`.
- Metadata is cached (default 12h), so SPs may not pick up new certs immediately after rotation.
