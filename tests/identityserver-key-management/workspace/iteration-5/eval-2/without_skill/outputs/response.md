# Using a Static Signing Certificate

To switch from automatic key management to a static PFX certificate, disable key management and register the certificate as your signing credential with RS256.

## Program.cs

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Read the certificate password from configuration
var certPassword = builder.Configuration["Certificates:SigningPassword"];

// Load the PFX certificate from disk
var signingCert = new X509Certificate2("/certs/signing.pfx", certPassword);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Disable automatic key management so we use our own static key
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

// Register the certificate as the signing credential using RS256
idsvrBuilder.AddSigningCredential(signingCert, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## appsettings.json

Store the password in configuration (use secrets/environment variables in production):

```json
{
  "Certificates": {
    "SigningPassword": "your-password-here"
  }
}
```

## Notes

- `SecurityAlgorithms.RsaSha256` is the RS256 algorithm identifier.
- The PFX file must include the private key.
- With automatic key management disabled, you're responsible for rotating this certificate before it expires. Rotate carefully so existing tokens remain valid.
- All existing clients, scopes, and identity resources are preserved.
