```csharp
using System.Security.Cryptography.X509Certificates;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var password = builder.Configuration["SigningCertificate:Password"];
var certificate = X509CertificateLoader.LoadPkcs12FromFile("/certs/signing.pfx", password);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;            // disable automatic key management
});

idsvrBuilder.AddSigningCredential(certificate, SecurityAlgorithms.RsaSha256);   // RS256

idsvrBuilder
    .AddInMemoryClients(/* unchanged */)
    .AddInMemoryApiScopes(/* unchanged */)
    .AddInMemoryIdentityResources(/* unchanged */);
```

Notes:
- `X509CertificateLoader` replaces the obsolete `X509Certificate2` constructors. Provide the password via user-secrets/env var/secret store (`SigningCertificate__Password`), not in `appsettings.json`.
- The first credential added is the default. IdentityServer doesn't enforce certificate expiry; that's your policy.
- Static keys mean manual rotation: use the phased approach (announce new key via `AddValidationKey`, wait for JWKS caches, swap signing, keep the old as a validation key until tokens expire, then remove it).
- If you enable SAML later, a static key must be an X.509 certificate with private key, which a PFX is.
