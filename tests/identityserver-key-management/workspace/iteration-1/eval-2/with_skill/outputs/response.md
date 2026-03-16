# Using Static Signing Keys from a PFX Certificate

Here's the updated `Program.cs` that disables automatic key management, loads a PFX certificate from disk, and registers it as the signing credential with RS256:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using System.Security.Cryptography.X509Certificates;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Disable automatic key management — we'll manage keys manually
    options.KeyManagement.Enabled = false;
})
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

// Load the PFX certificate from disk
var certPassword = builder.Configuration["SigningCertificate:Password"];
var certBytes = File.ReadAllBytes("/certs/signing.pfx");
var certificate = X509CertificateLoader.LoadPkcs12(certBytes, certPassword);

// Register as the signing credential with RS256
idsvrBuilder.AddSigningCredential(certificate, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`KeyManagement.Enabled = false`** disables the automatic key management system. You are now fully responsible for key rotation.

2. **`X509CertificateLoader.LoadPkcs12`** is the recommended way to load PFX certificates in .NET 9+. The older `new X509Certificate2(path, password)` constructor is deprecated.

3. **Certificate password from configuration** — the password is loaded from `builder.Configuration` rather than being hardcoded. Add it to your secrets or environment variables:
   ```json
   {
     "SigningCertificate": {
       "Password": "your-certificate-password"
     }
   }
   ```

4. **`AddSigningCredential`** registers the certificate as the active signing key with RS256 (`SecurityAlgorithms.RsaSha256`).

5. The existing client and scope configuration is preserved unchanged.

When using static keys, you are responsible for key rotation. Consider using the phased rotation approach: first announce the new key via `AddValidationKey`, wait for caches to refresh, then swap to `AddSigningCredential` for the new key.
