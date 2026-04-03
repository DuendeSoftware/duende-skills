# Use a Static PFX Signing Key

To load a PFX certificate and use it as a static signing key, you'll need to disable the built-in key management and manually load the certificate.

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using System.Security.Cryptography.X509Certificates;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
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

// Load the certificate from the PFX file
var password = builder.Configuration["CertPassword"];
var cert = new X509Certificate2("/certs/signing.pfx", password);
idsvrBuilder.AddSigningCredential(cert, "RS256");

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This disables the automatic key management and uses your PFX certificate for signing tokens with the RS256 algorithm. Make sure to store the certificate password securely (e.g., in user secrets or environment variables).
