# Configure Multiple Signing Algorithms

To support RS256 and ES256 with a per-client override, you'll need to configure the key management signing algorithms and add a client that specifies its preferred algorithm.

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.SigningAlgorithms = new[]
        {
            new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256),
            new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256)
        };
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
        },
        new Client
        {
            ClientId = "mobile-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "com.myapp://callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }
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

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up RS256 as the default signing algorithm with ES256 as a secondary option. The `mobile-app` client is configured to receive identity tokens signed with ES256.
