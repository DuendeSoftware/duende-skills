# Supporting Multiple Signing Algorithms

Duende IdentityServer lets automatic key management maintain keys for more than one algorithm. You configure this through `KeyManagement.SigningAlgorithms`, providing a list of `SigningAlgorithmOptions`. The first algorithm in the list acts as the default for signing tokens, and the rest are additional algorithms whose keys are also published in the discovery document.

To make a specific client sign its identity tokens with ES256, set `AllowedIdentityTokenSigningAlgorithms` on that client.

## Program.cs

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // RS256 is listed first, so it is the default signing algorithm.
        // ES256 is available as a secondary algorithm.
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
            RedirectUris = { "https://localhost:5003/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Sign this client's identity tokens with ES256
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

- Because RS256 appears first in `SigningAlgorithms`, it's the default; ES256 keys are also generated and published so clients that require ES256 can validate their tokens.
- The `mobile-app` client restricts its identity token signing to ES256 via `AllowedIdentityTokenSigningAlgorithms`.
- If you need the RSA key exposed as an X.509 certificate (for example for consumers that require a certificate rather than a raw JWK), you may need to supply a certificate-backed key; check the Duende options for how RSA keys are represented in the discovery document for your clients.
