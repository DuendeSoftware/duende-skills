# Validating DPoP proof tokens in your API

## Package
```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```
(Note the capital N in `AspNetCore`.)

## Configuration

```csharp
// API Program.cs
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Add DPoP processing and validation to the "token" scheme
builder.Services.ConfigureDPoPTokensForScheme("token", options =>
{
    options.AllowBearerTokens = false;                                   // default
    options.ProofTokenExpirationMode = DPoPProofExpirationMode.IssuedAt; // default
});

// Replay detection is ON by default and needs a KEYED HybridCache
builder.Services.AddKeyedHybridCache(ServiceProviderKeys.ProofTokenReplayHybridCache);
```

Replay detection uses a keyed `HybridCache`; if enabled and not registered an `InvalidOperationException` is thrown when a proof is validated. For multiple instances also register an `IDistributedCache` (e.g. `AddStackExchangeRedisCache`) as the L2 cache so replays are detected across instances.

## What the library validates
1. The access token as normal
2. The proof from the `DPoP` header (JWT format, `dpop+jwt` type)
3. The `Authorization` header uses the `DPoP` scheme
4. The `cnf.jkt` matches the proof key
5. HTTP method and URL match the request
6. Replay (`jti`) detection
7. Nonce generation/validation, clock skew
8. Correct `WWW-Authenticate` error responses on failure

## Options (`DPoPOptions`, per scheme)

| Option | Default | Notes |
|---|---|---|
| `AllowBearerTokens` | `false` | `true` accepts Bearer and DPoP (migration) |
| `ProofTokenLifetime` | 5 s | |
| `ProofTokenExpirationMode` | `IssuedAt` | `IssuedAt`, `Nonce`, `Both` |
| `ProofTokenIssuedAtClockSkew` | 25 s | |
| `ProofTokenNonceClockSkew` | 5 s | |
| `ProofTokenValidationParameters` | `dpop+jwt`, RS/PS/ES algs | Restrict `ValidAlgorithms` |
| `EnableReplayDetection` | `true` | |

Nonces use Data Protection, so share keys across instances.
