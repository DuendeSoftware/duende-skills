# FAPI 2.0 Compliant IdentityServer Configuration

**FAPI 2.0 requires Enterprise Edition, version >= 7.3.**

## Server Configuration

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(opt =>
{
    // Key management with PS256 support
    opt.KeyManagement.SigningAlgorithms.Add(
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256));

    // DPoP signing algorithms (FAPI 2.0 compliant set)
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

    // FAPI 2.0 requires max 10 seconds JWT clock skew
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "fapi_client",
            
            // FAPI 2.0: confidential client with private_key_jwt
            RequireClientSecret = true,
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "{\"e\":\"AQAB\",\"kid\":\"fapi_key\",\"kty\":\"RSA\",\"n\":\"...\"}"
                }
            },
            
            // Authorization code flow
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://banking.example.com/callback" },
            
            // FAPI 2.0: sender-constrained tokens via DPoP
            RequireDPoP = true,
            
            // FAPI 2.0: PAR required
            RequirePushedAuthorization = true,
            
            // FAPI 2.0: PKCE required
            RequirePkce = true,
            
            // FAPI 2.0: no refresh token rotation (except extraordinary events)
            AllowOfflineAccess = true,
            RefreshTokenUsage = TokenUsage.ReUse,
            
            AllowedScopes = { "openid", "profile", "api1" }
        }
    });

// Distributed cache for DPoP replay detection
builder.Services.AddDistributedMemoryCache();

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## FAPI 2.0 Requirements Addressed

| Requirement | Configuration |
|---|---|
| Sender-constrained tokens | `RequireDPoP = true` |
| PAR required | `RequirePushedAuthorization = true` |
| Confidential client | `RequireClientSecret = true` with JWK secret |
| `private_key_jwt` authentication | `JsonWebKey` secret type |
| PS256 signing | `KeyManagement.SigningAlgorithms` includes PS256 |
| DPoP algorithms restricted | `DPoP.SupportedDPoPSigningAlgorithms` with PS/ES families |
| JWT clock skew max 10s | `JwtValidationClockSkew = TimeSpan.FromSeconds(10)` |
| PKCE required | `RequirePkce = true` |
| No refresh token rotation | `RefreshTokenUsage = TokenUsage.ReUse` |

## Additional FAPI 2.0 Notes

- Starting in v8.0, IdentityServer uses HTTP 303 redirects from POST endpoints (FAPI 2.0 Section 5.3.2.2)
- The `StrictClientAssertionAudienceValidation` option ensures the `aud` in client assertions is only the issuer URI
- Authorization code lifetime should be set to 60 seconds maximum for full FAPI 2.0 compliance
- Use `private_key_jwt` over mTLS for client authentication — it's simpler to maintain
