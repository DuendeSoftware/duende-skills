# Using a Static PFX Certificate for Token Signing

Here's the updated `Program.cs` that disables automatic key management and uses a static PFX certificate for signing:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using System.Security.Cryptography.X509Certificates;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Disable automatic key management
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

// Load the signing certificate from PFX file
var certPassword = builder.Configuration["CertificatePassword"];
var certificate = new X509Certificate2("/certs/signing.pfx", certPassword);

// Register as signing credential with RS256
idsvrBuilder.AddSigningCredential(certificate, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This disables the built-in automatic key management and instead loads a PFX certificate from `/certs/signing.pfx`. The certificate password is pulled from configuration so it's not hardcoded. The certificate is then registered as the signing credential using the RS256 algorithm.

Make sure the PFX file is accessible at the specified path in your deployment environment and that the password is stored securely (e.g., in user secrets or environment variables).
