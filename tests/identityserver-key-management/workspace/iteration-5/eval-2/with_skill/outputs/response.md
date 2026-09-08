# Static Signing Key from a PFX Certificate

To use a static signing key you need to do two things:

1. **Disable automatic key management** so IdentityServer doesn't generate/rotate its own keys.
2. **Register your certificate** as the signing credential with RS256.

The PFX password should come from configuration (never hard-coded). I'll read it from `builder.Configuration`, e.g. `SigningCertificate:Password`, which you can supply via `appsettings.json`, user secrets, or environment variables.

Load the certificate with `X509CertificateLoader.LoadPkcs12` (the modern .NET API that replaces the obsolete `new X509Certificate2(...)` constructor), then pass it to `AddSigningCredential` with `SecurityAlgorithms.RsaSha256` (which is RS256).

## Program.cs

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Load the PFX signing certificate from disk; password comes from configuration.
var pfxPassword = builder.Configuration["SigningCertificate:Password"];
var pfxBytes = File.ReadAllBytes("/certs/signing.pfx");
var signingCertificate = X509CertificateLoader.LoadPkcs12(pfxBytes, pfxPassword);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Turn off automatic key management: we manage the signing key ourselves.
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

// Register the static signing credential using RS256.
idsvrBuilder.AddSigningCredential(signingCertificate, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## appsettings.json (add the password entry)

For local development you can add the password here, but in production prefer user secrets / environment variables / a vault:

```json
{
  "SigningCertificate": {
    "Password": "your-pfx-password"
  }
}
```

## Notes

- **RS256** is represented by `SecurityAlgorithms.RsaSha256`. The PFX must contain the **private key** for signing to work.
- **Manual rotation:** With automatic key management disabled, you are now responsible for rotating this key. When you replace it, use the phased approach (announce the new key as a validation key first, then swap signing) so cached clients and in-flight tokens keep validating.
- **Certificate expiration:** IdentityServer does not enforce X.509 expiration for signing, but treat the expiry as a policy trigger to rotate.
- I kept all existing client, scope, and identity-resource registrations intact.
