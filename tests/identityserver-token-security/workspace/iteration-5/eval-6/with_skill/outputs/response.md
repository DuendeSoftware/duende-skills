# FAPI 2.0 compliant IdentityServer + client

The FAPI 2.0 Security Profile is the OAuth hardening baseline for high-value scenarios like open banking. Below is a complete server configuration and a FAPI 2.0 compliant client using authorization code flow with DPoP and PAR.

> **Version/edition:** FAPI 2.0 support (and the conformance report) requires Duende IdentityServer **Enterprise Edition, v7.3+** (report v8.0+). Your project targets 8.0.

## Server configuration (`Program.cs`)

```csharp
using Duende.IdentityServer.Configuration;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(opt =>
{
    // 1. PS256 signing key support (RSASSA-PSS SHA-256)
    opt.KeyManagement.SigningAlgorithms.Add(
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256));

    // 2. DPoP signing algorithms — PS256/384/512 and ES256/384/512
    opt.DPoP.SupportedDPoPSigningAlgorithms =
    [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // 3. Client assertion (private_key_jwt) signing algorithms
    opt.SupportedClientAssertionSigningAlgorithms =
    [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // 4. Request object (JAR) signing algorithms
    opt.SupportedRequestObjectSigningAlgorithms =
    [
        SecurityAlgorithms.RsaSsaPssSha256,
        SecurityAlgorithms.RsaSsaPssSha384,
        SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256,
        SecurityAlgorithms.EcdsaSha384,
        SecurityAlgorithms.EcdsaSha512
    ];

    // 5. FAPI 2.0 requires clock skew no more than 10 seconds into the future
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);

    // 6. PAR required globally (FAPI 2.0 mandates PAR)
    opt.PushedAuthorization.Required = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## FAPI 2.0 compliant client

A FAPI 2.0 client must be **confidential** (authenticating with `private_key_jwt` or mTLS — **not** a shared secret), issue **sender-constrained** tokens (DPoP or mTLS), use **PAR**, use **PKCE**, and avoid refresh-token rotation (`RefreshTokenUsage = ReUse`).

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "openbanking_app",

    // Authorization code flow + PKCE
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
    RequirePkce = true,

    // Confidential client authenticating via private_key_jwt (JWK secret, NOT a shared secret)
    RequireClientSecret = true,
    ClientSecrets =
    {
        new Duende.IdentityServer.Models.Secret
        {
            Type = Duende.IdentityServer.IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{'kty':'RSA','kid':'openbanking-sign','n':'...','e':'AQAB'}"
        }
    },

    RedirectUris = { "https://openbanking.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    AllowOfflineAccess = true,

    // Sender-constrained tokens via DPoP
    RequireDPoP = true,

    // FAPI 2.0 mandates PAR
    RequirePushedAuthorization = true,

    // No refresh token rotation — reuse refresh tokens
    RefreshTokenUsage = Duende.IdentityServer.Models.TokenUsage.ReUse
}
```

## Why each setting matters (FAPI 2.0 checklist)

| Requirement | Setting |
| --- | --- |
| Asymmetric signing (PS256) | `KeyManagement.SigningAlgorithms` += `RsaSsaPssSha256` |
| Sender-constrained tokens | `RequireDPoP = true` + `DPoP.SupportedDPoPSigningAlgorithms` |
| PAR required | `PushedAuthorization.Required = true` / `RequirePushedAuthorization = true` |
| Confidential client, no shared secret | `RequireClientSecret = true` + `JsonWebKey` secret (private_key_jwt) |
| Strong client assertion / request object algs | `SupportedClientAssertionSigningAlgorithms`, `SupportedRequestObjectSigningAlgorithms` |
| Clock skew ≤ 10s | `JwtValidationClockSkew = TimeSpan.FromSeconds(10)` |
| No refresh rotation | `RefreshTokenUsage = ReUse` |
| PKCE | `RequirePkce = true` |

## API side (validating FAPI 2.0 tokens)

On the resource server, restrict the DPoP proof algorithms explicitly so weaker algorithms are not accepted:

```csharp
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
        dpopOptions.ProofTokenValidationParameters.ValidAlgorithms =
        [
            SecurityAlgorithms.RsaSsaPssSha256,
            SecurityAlgorithms.RsaSsaPssSha384,
            SecurityAlgorithms.RsaSsaPssSha512,
            SecurityAlgorithms.EcdsaSha256,
            SecurityAlgorithms.EcdsaSha384,
            SecurityAlgorithms.EcdsaSha512
        ];
    });
```

Start with `private_key_jwt` (as above) rather than mTLS — both are FAPI 2.0 compliant, but mTLS is harder to operate in production. From v8.0, IdentityServer also unconditionally uses HTTP 303 redirects from POST endpoints, per FAPI 2.0 §5.3.2.2.
