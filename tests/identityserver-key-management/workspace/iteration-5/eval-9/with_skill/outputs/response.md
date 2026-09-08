# SAML Signing Keys on IdentityServer (Static Key Management)

## What signing key you need: an X.509 certificate with a private key

Because you're using **static key management**, enabling the SAML component means you must configure an **X.509 signing certificate that includes a private key**. SAML is different from OIDC here: SAML IdP **metadata** publishes signing material as `<X509Certificate>` elements, so the signing credential has to *be* a certificate, not just a raw key.

## Why `AddDeveloperSigningCredential()` won't work for SAML

`AddDeveloperSigningCredential()` registers a **raw RSA key** (it persists a `tempkey.jwk`), not an X.509 certificate. Under **static** key management, IdentityServer will **not** auto-wrap a manually registered raw RSA key into an X.509 certificate for SAML. Since SAML metadata requires a certificate, that raw key has nothing to publish as `<X509Certificate>` and SAML signing/metadata fails.

The fix under static management is to register a real certificate with a private key, for example:

```csharp
var bytes = File.ReadAllBytes("saml-signing.pfx");
var certificate = X509CertificateLoader.LoadPkcs12(bytes, pfxPassword);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false; // static key management
});
idsvrBuilder.AddSigningCredential(certificate, SecurityAlgorithms.RsaSha256);
```

The SAML default signing service supports **RSA only** — `UseX509Certificate` is not supported for EC (`ES`) keys. For a different certificate, independent rotation, or an external key system, implement a custom `ISamlSigningService`.

## How rotation is shared between OIDC and SAML

OIDC and SAML **share the same signing credentials and the same rotation schedule** — one key store, one set of keys. The rotated public keys are published **in parallel** through two channels:

- **OIDC** — the JWKS (`jwks_uri`) discovery endpoint.
- **SAML** — the IdP **metadata** document (as X.509 certificates).

Because it's one schedule, the same lifecycle knobs govern SAML rollover:

- **`PropagationTime`** — how long a new key/certificate is *published before it starts signing*. Set this long enough for all Service Providers (SPs) to refresh their copy of your IdP metadata before you begin signing with the new certificate.
- **`RetentionDuration`** — how long the *previous* certificate stays published for validation after rotation, so SPs can still validate recently-issued SAML messages (and old OIDC tokens) during the overlap.

One caveat: SPs that have your IdP certificate **statically configured** (rather than reading metadata dynamically) must be updated with the new certificate on every rotation.

## Note on Automatic Key Management (for contrast)

If you were instead using **Automatic Key Management**, you would **not** need to provide a certificate or set `UseX509Certificate` just to enable SAML. The SAML component **auto-wraps** the automatically managed RSA keys into self-signed X.509 certificates for metadata. The certificate requirement above is specific to the **static** key management you're using.
