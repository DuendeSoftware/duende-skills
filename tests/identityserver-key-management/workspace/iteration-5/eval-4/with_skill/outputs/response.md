# Multiple Signing Algorithms (RS256 default + ES256)

Automatic Key Management can manage keys for several algorithms at once. Set `KeyManagement.SigningAlgorithms` to an array of `SigningAlgorithmOptions`. **The first entry in the array is the default** used for signing when a client/resource doesn't request a specific algorithm.

- **RS256 as default, with X.509 wrapping** → first entry: `new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true }`. `UseX509Certificate = true` makes IdentityServer wrap the managed RSA key in a self-signed X.509 certificate (useful for older clients and for SAML).
- **ES256 as secondary** → `new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256)`.
- **`mobile-app` uses ES256 for identity tokens** → set `AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }` on that client.

## Program.cs

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.SigningAlgorithms = new[]
        {
            // Default: RS256, wrapped in a self-signed X.509 certificate
            new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true },

            // Secondary: ES256 (ECDSA)
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
            RedirectUris = { "https://localhost:5003/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" },

            // This client's identity tokens must be signed with ES256
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

## Notes

- **Order matters:** RS256 is listed first, so it is the default signing algorithm; ES256 keys are still managed and published in JWKS, and are used for the `mobile-app` client because of its `AllowedIdentityTokenSigningAlgorithms` restriction.
- IdentityServer will now maintain and rotate separate keys for both RS256 and ES256, all published in the discovery/JWKS endpoint.
- `UseX509Certificate` applies to RSA keys only; it is **not** supported for EC (`ES`) keys, so ES256 is registered without it.
- If you later add SAML, the RS256 X.509-wrapped key is what SAML needs.
