# InvalidOperationException on first DPoP request

`AddDistributedMemoryCache` alone isn't enough: the DPoP validation needs a **replay cache** service. Duende's DPoP implementation for JWT bearer uses an `IReplayCache` to detect reused proof `jti` values, and the default implementation is built on `IDistributedCache`. The exception is typically a missing dependency resolved lazily on the first DPoP request.

Things to check:

```csharp
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSingleton<IReplayCache, DefaultReplayCache>(); // register the replay cache if not registered
// (or your own implementation backed by Redis)

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", o => { o.Authority = "https://identity.example.com"; o.Audience = "api1"; });

builder.Services.ConfigureDPoPTokensForScheme("token"); // scheme name must match exactly
```

Also verify:
- The scheme name in `ConfigureDPoPTokensForScheme` matches the `AddJwtBearer` scheme.
- `UseAuthentication()` is called.
- Read the exception message—it names the missing service. I can't be certain which service from the description alone; if it persists, post the full stack trace.
