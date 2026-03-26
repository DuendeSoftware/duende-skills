# Multiple Signing Algorithms with Per-Client Override

Here's how to configure RS256 (with X.509 wrapping) as the default and ES256 as secondary, plus a client using ES256 for identity tokens.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Configure multiple signing algorithms
    options.KeyManagement.SigningAlgorithms = new[]
    {
        // RS256 as default (first in list), with X.509 certificate wrapping
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true },
        // ES256 as secondary algorithm
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
            // Override: use ES256 for identity tokens
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

## How It Works

- The `SigningAlgorithms` array determines which algorithms get managed keys. The **first** entry is the default.
- `UseX509Certificate = true` on RS256 wraps the RSA key in an X.509 certificate, which is required by some older OIDC/JWT libraries.
- The `mobile-app` client's `AllowedIdentityTokenSigningAlgorithms` overrides the default for identity tokens only.
- Access tokens still use the default RS256 unless the `ApiResource` has `AllowedAccessTokenSigningAlgorithms` set.
