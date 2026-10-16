# DPoP validation: nonces, replay detection, ES256 only, 3 instances

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

```csharp
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.ConfigureDPoPTokensForScheme("token", options =>
{
    options.AllowBearerTokens = false;
    options.ProofTokenExpirationMode = DPoPProofExpirationMode.Nonce; // server-issued nonces
    options.EnableReplayDetection = true;                              // default
    options.ProofTokenValidationParameters.ValidAlgorithms = [ SecurityAlgorithms.EcdsaSha256 ]; // ES256 only
});

// Replay detection requires a KEYED HybridCache
builder.Services.AddKeyedHybridCache(ServiceProviderKeys.ProofTokenReplayHybridCache);

// Multi-instance: L2 distributed cache so replays are detected across instances
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "redis:6379");

// Nonces are Data Protection based: share keys across instances
builder.Services.AddDataProtection()
    .SetApplicationName("my-api")
    .PersistKeysToStackExchangeRedis(ConnectionMultiplexer.Connect("redis:6379"), "DataProtection-Keys");
```

## Why each piece matters
- **Nonces**: with `Nonce` mode the API answers `401` with `use_dpop_nonce` and a `DPoP-Nonce` header; the client retries with the nonce. Use `Both` to also check `iat`. `ProofTokenNonceClockSkew` (5 s default) covers skew between API instances.
- **Replay detection** is on by default and caches the proof `jti` for lifetime + skew in a keyed `HybridCache`. HybridCache is in-memory by default (per instance), so with 3 instances a replay against a different instance would pass; registering an `IDistributedCache` (Redis, SQL Server) as L2 shares it. If the keyed cache is missing, an `InvalidOperationException` is thrown when validating a proof.
- **Data Protection**: if the three instances don't share keys (and app name), nonces issued by one instance are rejected by the others.
- **ES256 only**: the default accepts RS/PS/ES 256/384/512 with `dpop+jwt`; restrict `ProofTokenValidationParameters.ValidAlgorithms`. Without this the API may accept weaker algorithms.
- Other defaults: `ProofTokenLifetime` 5 s, `ProofTokenMaxLength` 4000.

Make sure the clients are configured with ES256 keys (generate `ECDsa` P-256 JWKs), and the IdentityServer `opt.DPoP.SupportedDPoPSigningAlgorithms` includes ES256 so tokens can be issued.
