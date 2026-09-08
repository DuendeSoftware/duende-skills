# Why SAML Signing Fails with `AddDeveloperSigningCredential()`

## Short version

SAML assertions and responses must be signed with an **X.509 certificate**. `AddDeveloperSigningCredential()` is designed for OpenID Connect/JWT signing and typically produces a temporary in-memory RSA key rather than a proper X.509 signing certificate. SAML's XML signature (XML-DSig) machinery generally expects a certificate, so signing fails or produces something the SP can't validate.

## What SAML signing needs

- A certificate (`X509Certificate2`) that includes a **private key**, used to compute the XML signature over the assertion/response.
- The corresponding public certificate published in your IdP metadata so SPs can validate signatures.

`AddDeveloperSigningCredential()` doesn't give you a stable, exportable X.509 certificate with published metadata, which is why it's unsuitable here (and it's development-only regardless).

## What to use instead

Load a real X.509 certificate with its private key and register it as your signing credential:

```csharp
var cert = new X509Certificate2("saml-signing.pfx", "password",
    X509KeyStorageFlags.EphemeralKeySet);

builder.Services.AddIdentityServer()
    .AddSigningCredential(cert);
```

For development you can create a self-signed certificate (via `dotnet dev-certs`, OpenSSL, or `New-SelfSignedCertificate`) and load it the same way. For production, use a certificate from your certificate store, Key Vault, or HSM.

## Tips

1. Make sure the certificate's private key is accessible to the app (file permissions / key storage flags).
2. Publish the public cert in metadata and share it with your SPs so they can validate.
3. Plan for rotation — keep the old cert available for validation during the overlap window.
4. Confirm the SP is configured to expect signed assertions/responses and that the signature algorithm (e.g., RSA-SHA256) matches.

## Note

If you're relying on IdentityServer's automatic key management for OIDC, be aware SAML signing may need its own explicitly configured X.509 certificate; check your SAML library's documentation for exactly how it selects the signing certificate.
