# FAPI 2.0 Compliant IdentityServer Configuration

The FAPI 2.0 Security Profile defines strict requirements for authorization servers in high-value scenarios like open banking, e-health, and e-government. Duende IdentityServer supports FAPI 2.0 compliance starting with **Enterprise Edition >= 7.3**.

## Complete Server Configuration

```csharp
// Program.cs
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(opt =>
{
    // Key management with PS256 support (required by FAPI 2.0)
    opt.KeyManagement.SigningAlgorithms.Add(
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256));

    // DPoP signing algorithms — restrict to PS and ES families
    opt.DPoP.SupportedDPoPSigningAlgorithms = [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // Client assertion signing algorithms
    opt.SupportedClientAssertionSigningAlgorithms = [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // Request object signing algorithms
    opt.SupportedRequestObjectSigningAlgorithms = [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // FAPI 2.0 requires JWT clock skew max 10 seconds
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);

    // Require PAR globally for all clients
    opt.PushedAuthorization.Required = true;
    opt.PushedAuthorization.Lifetime = 600; // 10 minutes (int, seconds)
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "fapi_banking_client",

            // FAPI 2.0: Only confidential clients with private_key_jwt authentication
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "{'e':'AQAB','kid':'fapi_key','kty':'RSA','n':'...'}"
                }
            },

            // Authorization code flow (FAPI 2.0 only supports code flow)
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = true,

            RedirectUris = { "https://banking.example.com/callback" },
            AllowOfflineAccess = true,
            AllowedScopes = { "openid", "profile", "api1" },

            // Sender-constrained tokens via DPoP
            RequireDPoP = true,

            // PAR required (also enforced globally, but explicit per-client for safety)
            RequirePushedAuthorization = true,

            // FAPI 2.0: No refresh token rotation (except extraordinary events)
            RefreshTokenUsage = TokenUsage.ReUse
        }
    ];
}
```

## FAPI 2.0 Requirements Checklist

| Requirement | Configuration |
|---|---|
| Only confidential clients | `RequireClientSecret = true` |
| Sender-constrained tokens | `RequireDPoP = true` (or mTLS) |
| mTLS or private_key_jwt auth | `JsonWebKey` secret type |
| PAR required | `RequirePushedAuthorization = true` |
| PKCE required | `RequirePkce = true` |
| No refresh token rotation | `RefreshTokenUsage = TokenUsage.ReUse` |
| PS256 signing | `KeyManagement.SigningAlgorithms` with PS256 |
| JWT clock skew <= 10s | `JwtValidationClockSkew = TimeSpan.FromSeconds(10)` |
| Auth code max 60s | `AuthorizationCodeLifetime = 60` |

## API Configuration for FAPI 2.0

```csharp
// API Program.cs
builder.Services.AddAuthentication()
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.ConfigureDPoPTokensForScheme(JwtBearerDefaults.AuthenticationScheme,
    dpopOptions =>
    {
        dpopOptions.ProofTokenValidationParameters.ValidAlgorithms = [
            SecurityAlgorithms.RsaSsaPssSha256,
            SecurityAlgorithms.RsaSsaPssSha384,
            SecurityAlgorithms.RsaSsaPssSha512,
            SecurityAlgorithms.EcdsaSha256,
            SecurityAlgorithms.EcdsaSha384,
            SecurityAlgorithms.EcdsaSha512
        ];
    });
```

## Key Decisions

- **Private key JWT over mTLS**: Start with private key JWTs for client authentication. mTLS is relatively challenging to maintain in production with certificate rotation, distribution, and revocation. Both are FAPI 2.0 compliant.
- **DPoP over mTLS for token binding**: DPoP works at the application layer and doesn't require TLS infrastructure changes. Both are accepted by FAPI 2.0.
