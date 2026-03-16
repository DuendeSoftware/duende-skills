# Multiple Signing Algorithms with Per-Client Override

Here's the updated `Program.cs` that configures RS256 (with X.509 wrapping) as the default algorithm, ES256 as a secondary algorithm, and a `mobile-app` client that uses ES256 for identity tokens:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Configure multiple signing algorithms
    options.KeyManagement.SigningAlgorithms = new[]
    {
        // RS256 with X.509 wrapping — first entry is the default
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
        {
            UseX509Certificate = true
        },

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
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "com.example.mobileapp://callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Use ES256 for this client's identity tokens
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

## How This Works

### Multiple Signing Algorithms

`SigningAlgorithms` configures automatic key management to create and manage keys for each algorithm. The **first entry in the array is the default** — tokens are signed with RS256 unless overridden.

- **RS256 with `UseX509Certificate = true`**: Wraps the RSA key in an X.509 certificate. This is required for compatibility with some older clients/libraries that expect X.509-formatted keys in the JWKS endpoint.
- **ES256 (ECDSA)**: A more compact algorithm that produces smaller signatures. Useful for mobile clients where token size matters.

### Per-Client Algorithm Override

`AllowedIdentityTokenSigningAlgorithms` on the `mobile-app` client tells IdentityServer to sign identity tokens for this client using ES256 instead of the default RS256.

You can also override at the API Resource level using `AllowedAccessTokenSigningAlgorithms` to control which algorithm signs access tokens for a specific API:

```csharp
var api = new ApiResource("invoice")
{
    AllowedAccessTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }
};
```

### Key Discovery

Both RS256 and ES256 keys are published in the discovery document's `jwks_uri` endpoint, so clients and APIs can validate tokens signed with either algorithm.
