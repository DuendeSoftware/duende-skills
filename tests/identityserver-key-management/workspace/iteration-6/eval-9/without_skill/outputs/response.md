SAML assertions are XML-signed, and the XML signature (`ds:Signature` / `KeyInfo`) conventionally carries an **X.509 certificate**, which SPs import as trust metadata. So the SAML component requires a signing key that is an `X509Certificate2` (with private key), not a raw `RsaSecurityKey`. `AddDeveloperSigningCredential()` produces a raw RSA key with no certificate, so metadata can't publish an `X509Certificate` and signing can't be bound to it.

Configure:

```csharp
var cert = X509CertificateLoader.LoadPkcs12FromFile("signing.pfx", password);
builder.Services.AddIdentityServer()
    .AddSigningCredential(cert, SecurityAlgorithms.RsaSha256)
    .AddSaml();   // component registration
```

With automatic key management you'd set `UseX509Certificate = true` on the RSA algorithm option so the key is wrapped in a certificate.

Rotation: OIDC and SAML sign with the same IdentityServer key material (the credential store), so rotation is shared. With static keys, a rollover means: announce the new cert via `AddValidationKey` (JWKS and SAML metadata), switch signing credential, then retire the old one. SAML SPs must reload metadata, which is often manual, so allow longer propagation than for OIDC.
