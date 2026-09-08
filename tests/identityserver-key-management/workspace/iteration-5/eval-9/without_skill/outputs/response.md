# SAML Signing on IdentityServer

## What key you need

SAML relies on XML Signature, and SAML metadata publishes the signing key as an embedded X.509 certificate (`<ds:X509Certificate>`). So for the SAML component you need to configure an **X.509 certificate that contains a private key** (e.g. a `.pfx`) as your signing credential. The private key signs outgoing SAML assertions/responses; the public certificate is what you publish in your IdP metadata so service providers can verify signatures.

A typical setup loads a certificate and registers it as the signing credential:

```csharp
var cert = new X509Certificate2("saml-signing.pfx", password);

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false; // static keys
})
.AddSigningCredential(cert, SecurityAlgorithms.RsaSha256);
```

## Why `AddDeveloperSigningCredential()` doesn't work

`AddDeveloperSigningCredential()` is meant only for development. It creates a **temporary, raw RSA key** (stored as a `tempkey` file) rather than a real X.509 certificate. Two problems for SAML:

1. It's a raw key, **not a certificate**, so there's no X.509 certificate to embed in your SAML metadata.
2. It's ephemeral/regenerated, which would break any service provider that has already trusted a previous certificate.

For SAML you need a proper certificate (with a private key) that you control and can publish, not the developer convenience key.

## How rotation relates to OIDC and SAML

Both OIDC and SAML use the signing key(s) configured on IdentityServer to sign their tokens/messages. When you rotate a signing key you need to make sure both consumers can still validate:

- For **OIDC**, the public keys are exposed at the JWKS endpoint, and clients pick up new keys when they refresh discovery.
- For **SAML**, the certificate is published in your IdP metadata, and service providers must trust the new certificate — those with statically pinned certificates need to be updated manually.

Because of this, when you rotate you should keep the old certificate available for validation for a transition period (until previously issued tokens/assertions have expired and all consumers have picked up the new certificate) before removing it, rather than swapping keys instantly. This is the same phased approach recommended for static key rotation generally.
