# Configuring DPoP validation

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Configure DPoP on the IServiceCollection, NOT inside AddJwtBearer
builder.Services.ConfigureDPoPTokensForScheme("token");

// Replay detection (on by default) requires a keyed HybridCache
builder.Services.AddKeyedHybridCache(ServiceProviderKeys.ProofTokenReplayHybridCache);

builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected" }));
app.Run();
```

```csharp
// ❌ Wrong – not valid inside the JwtBearer options lambda
.AddJwtBearer("token", o => { o.ConfigureDPoPTokensForScheme("token"); });
```

## What it validates
1. The `DPoP` proof JWT in the request header.
2. That the access token's `cnf.jkt` equals the thumbprint of the proof's key.
3. That the proof is bound to the request's HTTP method and URL.
4. Replay detection via the keyed `HybridCache`; nonces use Data Protection.

## Notes
- Scheme name in `ConfigureDPoPTokensForScheme` must match the `AddJwtBearer` scheme (`token`).
- **Multiple instances**: also register a distributed cache (e.g. Redis) so replays are detected across nodes; with `Nonce` mode, share Data Protection keys.
- Per-scheme `DPoPOptions`: `AllowBearerTokens`, `ProofTokenLifetime` (5s), `ProofTokenExpirationMode` (`IssuedAt`/`Nonce`/`Both`), `ProofTokenIssuedAtClockSkew` (25s), `ProofTokenNonceClockSkew` (5s), `ProofTokenMaxLength`, `ProofTokenValidationParameters`, `EnableReplayDetection`.
- If the API returns `use_dpop_nonce`, the client must retry with the value from the `DPoP-Nonce` response header.
- Clients send `Authorization: DPoP <token>` plus a `DPoP` header.
