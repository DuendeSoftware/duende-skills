# Configure Static Signing Key from PFX Certificate

To use a static signing key instead of automatic key management, you need to:
1. Disable automatic key management
2. Load the X.509 certificate from the PFX file
3. Register it as the signing credential with RS256

Update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;
using System.Security.Cryptography.X509Certificates;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Disable automatic key management since we're using static keys
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

// Load the signing certificate from disk
var certPassword = builder.Configuration["CertificatePassword"];
var certBytes = File.ReadAllBytes("/certs/signing.pfx");
var certificate = X509CertificateLoader.LoadPkcs12(certBytes, certPassword);

// Register it as the signing credential with RS256
idsvrBuilder.AddSigningCredential(certificate, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Configuration

Add the certificate password to your configuration (e.g., `appsettings.json` or user secrets / environment variables):

```json
{
  "CertificatePassword": "your-certificate-password"
}
```

> **Important:** Never store the certificate password in plain text in `appsettings.json` for production. Use user secrets, environment variables, or a secret manager like Azure Key Vault.

## Notes

- `KeyManagement.Enabled = false` disables automatic key creation and rotation. You are fully responsible for key lifecycle.
- `X509CertificateLoader.LoadPkcs12` is the modern .NET API for loading PFX/PKCS12 certificates (replacing the older `X509Certificate2` constructors).
- `SecurityAlgorithms.RsaSha256` corresponds to the `RS256` algorithm.
- When using static keys, you'll need to handle key rotation manually using a phased approach (announce new key, switch signing, remove old key).
