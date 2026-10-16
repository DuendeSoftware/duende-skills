# FAPI 2.0 configuration (Enterprise Edition ≥ 7.3)

## Server

```csharp
builder.Services.AddIdentityServer(opt =>
{
    // Key management with PS256
    opt.KeyManagement.SigningAlgorithms.Add(
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSsaPssSha256));

    // DPoP proof algorithms
    opt.DPoP.SupportedDPoPSigningAlgorithms = [
        SecurityAlgorithms.RsaSsaPssSha256, SecurityAlgorithms.RsaSsaPssSha384, SecurityAlgorithms.RsaSsaPssSha512,
        SecurityAlgorithms.EcdsaSha256, SecurityAlgorithms.EcdsaSha384, SecurityAlgorithms.EcdsaSha512 ];

    // private_key_jwt client assertions
    opt.SupportedClientAssertionSigningAlgorithms = [ /* same list */ ];

    // Signed request objects
    opt.SupportedRequestObjectSigningAlgorithms = [ /* same list */ ];

    // Max 10 seconds future skew
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);

    // Only issuer accepted as aud in client assertions
    opt.StrictClientAssertionAudienceValidation = true;

    // PAR globally
    opt.PushedAuthorization.Required = true;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);
```
v8.0 unconditionally uses HTTP 303 redirects from POST endpoints (FAPI 2.0 §5.3.2.2). Resource owner password grant is rejected by default.

## FAPI 2.0 client

```csharp
new Client
{
    ClientId = "fapi_client",
    RequireClientSecret = true,                       // confidential only
    ClientSecrets =
    [
        new Secret { Type = IdentityServerConstants.SecretTypes.JsonWebKey, Value = "<JWK public key>" } // private_key_jwt
    ],
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = [ "https://example.com/callback" ],
    AllowOfflineAccess = true,
    AllowedScopes = [ "openid", "profile", "api" ],

    RequireDPoP = true,                               // sender-constrained tokens
    DPoPValidationMode = DPoPTokenExpirationValidationMode.Nonce, // server-provided nonce
    RequirePushedAuthorization = true,                // PAR
    AuthorizationCodeLifetime = 60,                   // max 60 s
    RefreshTokenUsage = TokenUsage.ReUse              // no refresh token rotation
}
```

## API

```csharp
builder.Services.AddAuthentication().AddJwtBearer(o =>
{
    o.Authority = configuration.Authority;
    o.TokenValidationParameters.ValidateAudience = false;
    o.MapInboundClaims = false;
    o.TokenValidationParameters.ValidTypes = ["at+jwt"];
});

builder.Services.ConfigureDPoPTokensForScheme(JwtBearerDefaults.AuthenticationScheme, d =>
{
    d.ProofTokenValidationParameters.ValidAlgorithms = [ /* PS*/ES* list */ ];
});
builder.Services.AddKeyedHybridCache(ServiceProviderKeys.ProofTokenReplayHybridCache);
```

## Checklist
| Requirement | How |
|---|---|
| Discovery metadata | default |
| No ROPC | default |
| Confidential clients only | `RequireClientSecret = true` |
| Sender-constrained tokens | DPoP or mTLS |
| private_key_jwt or mTLS auth | JWK/cert secrets |
| Strict client assertion `aud` | `StrictClientAssertionAudienceValidation` |
| No refresh rotation | `RefreshTokenUsage = ReUse` |
| DPoP nonce | `DPoPValidationMode` |
| Code ≤ 60 s | `AuthorizationCodeLifetime = 60` |
| Clock skew ≤ 10 s | `JwtValidationClockSkew` |
| PAR | client or global |
| PKCE | `RequirePkce = true` |

Start with private key JWT rather than mTLS: mTLS is harder to run in production. Also, for multiple API instances, register a distributed cache and share Data Protection keys.
