# Multi-Algorithm Signing Configuration

To support multiple signing algorithms in IdentityServer:

## Updated Program.cs

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
            ClientSecrets = { new Secret("mobile_secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "myapp://callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowedIdentityTokenSigningAlgorithms = { "ES256" }
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

RS256 is configured first as the default, with ES256 as secondary. The mobile-app client uses ES256 for identity tokens.
