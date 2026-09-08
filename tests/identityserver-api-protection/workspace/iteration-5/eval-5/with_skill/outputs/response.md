# Configuring DPoP validation for your JWT bearer API

DPoP (RFC 9449) binds an access token to a client-held key. The client sends a `DPoP` proof JWT in a header alongside the sender-constrained access token. The API must validate that proof, confirm it matches the token's `cnf.jkt` thumbprint, and reject replays.

Duende ships this in the `Duende.AspNetCore.Authentication.JwtBearer` package via the `ConfigureDPoPTokensForScheme` extension. The important detail: **`ConfigureDPoPTokensForScheme` is called on `IServiceCollection` (`builder.Services`), not inside the `AddJwtBearer` options lambda.**

## 1. Add the package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## 2. Program.cs

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// DPoP replay/nonce detection requires a distributed cache.
builder.Services.AddDistributedMemoryCache(); // swap for Redis/SQL in production

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Configure DPoP for the "token" scheme — on the service collection, NOT
// inside the AddJwtBearer lambda.
builder.Services.ConfigureDPoPTokensForScheme("token");

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## What `ConfigureDPoPTokensForScheme("token")` does

1. Validates the `DPoP` proof JWT from the request header.
2. Confirms the `jkt` (JWK thumbprint) in the access token's `cnf` claim matches the proof key.
3. Verifies the proof is bound to the correct HTTP method and URL (`htm`/`htu`).
4. Uses `IDistributedCache` for nonce/replay detection — which is why the distributed cache registration is mandatory.

## Common mistakes

```csharp
// ❌ WRONG — DPoP configured inside the AddJwtBearer lambda
.AddJwtBearer("token", options =>
{
    options.ConfigureDPoPTokensForScheme("token"); // not valid here
});

// ✅ CORRECT — on IServiceCollection, plus a distributed cache
builder.Services.AddDistributedMemoryCache();
builder.Services.ConfigureDPoPTokensForScheme("token");
```

Also keep `ValidTypes = ["at+jwt"]` on the JWT handler so identity tokens can't be replayed as access tokens. If the API responds with `use_dpop_nonce`, the client must retry using the nonce from the `DPoP-Nonce` response header.
