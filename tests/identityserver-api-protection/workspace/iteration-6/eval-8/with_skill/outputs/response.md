# Missing: the keyed HybridCache for DPoP replay detection

`AddDistributedMemoryCache()` isn't what DPoP replay detection resolves. Replay detection (on by default) needs a **keyed `HybridCache`** registered under `ServiceProviderKeys.ProofTokenReplayHybridCache`. Without it, the first DPoP proof throws `InvalidOperationException`.

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.ConfigureDPoPTokensForScheme("token");

// The missing piece:
builder.Services.AddKeyedHybridCache(ServiceProviderKeys.ProofTokenReplayHybridCache);

// For multi-instance deployments, also register a distributed cache (e.g. Redis)
// so HybridCache's L2 can detect replays across instances:
// builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "...");
```

Notes:
- `AddDistributedMemoryCache()` is in-process only. It can serve as the L2 backing, but is not a substitute for the keyed registration, and doesn't give cross-instance replay detection.
- `ConfigureDPoPTokensForScheme` goes on `IServiceCollection`, not in the `AddJwtBearer` lambda, and its scheme name must match.
- If you disable replay detection (`EnableReplayDetection = false`), the cache isn't required, but that weakens protection.
- With `ProofTokenExpirationMode = Nonce` or `Both`, share Data Protection keys across instances.
