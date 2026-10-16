**Which key:** with static key management you must configure an **X.509 signing certificate with a private key**, e.g.

```csharp
var cert = X509CertificateLoader.LoadPkcs12FromFile("signing.pfx", password);
builder.Services.AddIdentityServer(o => o.KeyManagement.Enabled = false)
    .AddSigningCredential(cert, SecurityAlgorithms.RsaSha256);
```

**Why `AddDeveloperSigningCredential()` fails:** SAML IdP metadata requires X.509 certificates, not raw keys. The developer credential is a raw RSA key, and a manually registered raw RSA key cannot be auto-wrapped into a certificate for SAML. (With *automatic* key management, the SAML component auto-wraps managed RSA keys in self-signed certificates, so you don't need `UseX509Certificate` just to enable SAML.)

Constraints: the default SAML signing service supports RSA only (`UseX509Certificate` isn't supported for ES keys). For a different certificate, independent rotation, or an external key system, implement a custom `ISamlSigningService`.

**Shared rotation:** when SAML is enabled, IdentityServer uses the same signing credentials for OIDC tokens and SAML messages: one key store, one rotation schedule. Rotated public keys are published in parallel in the OIDC JWKS and the SAML IdP metadata.
- `PropagationTime`: how long a new managed key is published before signing; set it long enough for all SPs to refresh IdP metadata.
- `RetentionDuration`: keeps the previous certificate in metadata while SPs may still validate old messages (and old OIDC tokens remain valid).
- With static keys, do the phased rotation yourself (`AddValidationKey` for the new cert, wait, swap signing, keep the old as validation key, remove).
- SPs with statically configured IdP certificates must update them on every rotation.
