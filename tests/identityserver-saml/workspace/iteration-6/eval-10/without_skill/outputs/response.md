# SAML signing with AddDeveloperSigningCredential

`AddDeveloperSigningCredential()` creates a temporary RSA key stored in `tempkey.jwk`. It's meant for JWT signing during development. SAML XML signatures (XML-DSig) generally need an X.509 certificate (the certificate is embedded in metadata and the `KeyInfo` element so SPs can validate), and a bare JWK/RSA key has no certificate. So SAML signing can't use it.

What to use instead: a real X.509 certificate with a private key, registered as a signing credential:

```csharp
var cert = X509CertificateLoader.LoadPkcs12FromFile("idp-signing.pfx", password);
builder.Services.AddIdentityServer()
    .AddSigningCredential(cert, SecurityAlgorithms.RsaSha256)
    ...;
```

For dev, generate a self-signed cert (`dotnet dev-certs` or `New-SelfSignedCertificate`/openssl), load it from a file or certificate store, and for production load it from Key Vault or the machine store. Make sure the key is RSA (RS256), exportable/usable, and that SPs have the certificate from your metadata. If you use automatic key management, check that it's configured to produce X.509-backed keys, otherwise provide an explicit credential.
