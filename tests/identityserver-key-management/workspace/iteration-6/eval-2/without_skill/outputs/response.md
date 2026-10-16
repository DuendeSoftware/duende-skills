```csharp
using System.Security.Cryptography.X509Certificates;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var certPassword = builder.Configuration["SigningCertificate:Password"];
var cert = X509CertificateLoader.LoadPkcs12FromFile("/certs/signing.pfx", certPassword);

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = false;   // turn off automatic key management
    })
    .AddSigningCredential(cert, SecurityAlgorithms.RsaSha256)  // RS256
    .AddInMemoryClients(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryIdentityResources(/* ... */);
```

- `X509CertificateLoader` is the modern replacement for the obsolete `new X509Certificate2(path, password)` constructor (.NET 9+). 
- Keep the password out of source: `dotnet user-secrets` locally, environment variable `SigningCertificate__Password` or a secret store in production.
- The certificate must have a private key, RSA, and be valid; key size ≥ 2048.
- With static keys, rotation is your job: use `AddValidationKey` for the old cert while rolling over.
