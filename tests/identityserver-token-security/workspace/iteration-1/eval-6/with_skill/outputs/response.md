# FAPI 2.0 Compliant IdentityServer Configuration

FAPI 2.0 is a security profile for high-value APIs (open banking, e-health, e-government) that requires sender-constrained tokens, pushed authorization requests, and strong cryptographic algorithms.

## Server Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(opt =>
{
    // Key management with PS256 support
    opt.KeyManagement.SigningAlgorithms.Add(
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256));

    // DPoP signing algorithms (FAPI 2.0 requires PS/ES family)
    opt.DPoP.SupportedDPoPSigningAlgorithms = new[]
    {
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    };

    // Client assertion signing algorithms
    opt.SupportedClientAssertionSigningAlgorithms = new[]
    {
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    };

    // Request object signing algorithms
    opt.SupportedRequestObjectSigningAlgorithms = new[]
    {
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    };

    // FAPI 2.0 requires tight clock skew (max 10 seconds)
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);

    // PAR required globally
    opt.PushedAuthorization.Required = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "fapi_client",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = true,

            // JsonWebKey secret for private_key_jwt authentication
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "<JWK public key JSON here>"
                }
            },

            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true,

            // Sender-constrained tokens via DPoP
            RequireDPoP = true,

            // PAR required
            RequirePushedAuthorization = true,

            // FAPI 2.0: no refresh token rotation
            RefreshTokenUsage = TokenUsage.ReUse,

            // Short-lived access tokens
            AccessTokenLifetime = 300
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## FAPI 2.0 Requirements Mapping

| Requirement | Configuration |
|---|---|
| Sender-constrained tokens | `RequireDPoP = true` |
| PAR required | `RequirePushedAuthorization = true` + global `PushedAuthorization.Required = true` |
| Confidential client only | `RequireClientSecret = true` |
| Private key JWT auth | `JsonWebKey` secret type (not shared secret) |
| No refresh token rotation | `RefreshTokenUsage = TokenUsage.ReUse` |
| Clock skew ≤ 10 seconds | `JwtValidationClockSkew = TimeSpan.FromSeconds(10)` |
| PS256/ES256+ algorithms | Configured on DPoP, client assertions, and request objects |
| PKCE required | `RequirePkce = true` |

## Edition Requirements

FAPI 2.0 compliance requires **Enterprise Edition** of Duende IdentityServer (version >= 7.3). The conformance report is available in v8.0+.
