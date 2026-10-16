# DPoP validation in an API: nonces, replay detection, ES256, 3 instances

```
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

```csharp
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.MapInboundClaims = false;
    });

builder.Services.ConfigureDPoPTokensForScheme("token", o =>
{
    o.ValidationMode = ExpirationValidationMode.Nonce;      // require server-issued nonces
    o.AllowedProofAlgorithms = ["ES256"];                   // only ES256 proofs
    o.ProofTokenValidityDuration = TimeSpan.FromSeconds(10);
    o.ClockSkew = TimeSpan.FromSeconds(5);
});

// Replay cache + nonce data protection shared across instances
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "redis:6379");
builder.Services.AddTransient<IDPoPProofValidator, ...>(); // optional custom hook

builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redisConnection, "DataProtection-Keys")
    .SetApplicationName("my-api");
```

Key points for 3 instances:
- **Replay cache**: in-memory caches are per-instance, so a replayed proof sent to another instance would pass. Register a shared `IDistributedCache` (Redis/SQL) so the `jti` is recorded globally.
- **Nonces**: nonces are generated/validated using ASP.NET Data Protection, so all instances must share the same key ring and application name. Otherwise a nonce issued by instance A is rejected by instance B.
- Keep clocks synced (NTP) and clock skew small.
- On a missing/stale nonce the API returns 401 with `WWW-Authenticate: DPoP error="use_dpop_nonce"` and a `DPoP-Nonce` header; clients retry.

Note: exact option names can vary between package versions, so verify against the version you use.
