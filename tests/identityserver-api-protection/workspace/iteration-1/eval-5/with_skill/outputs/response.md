# Configuring DPoP (Demonstration of Proof-of-Possession) for Your API

DPoP binds an access token to a specific client's cryptographic key, preventing token theft and replay attacks.

## Install Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## Configure DPoP

```csharp
var builder = WebApplication.CreateBuilder(args);

// DPoP replay detection requires a distributed cache
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Configure DPoP on the service collection, NOT inside AddJwtBearer
builder.Services.ConfigureDPoPTokensForScheme("token");

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## Critical: ConfigureDPoPTokensForScheme Location

`ConfigureDPoPTokensForScheme` is called on `IServiceCollection` (i.e., `builder.Services`), **NOT** inside the `AddJwtBearer` options lambda. This is a common mistake:

```csharp
// ❌ WRONG: Inside AddJwtBearer lambda
.AddJwtBearer("token", options =>
{
    options.ConfigureDPoPTokensForScheme("token"); // This doesn't exist here
});

// ✅ CORRECT: On IServiceCollection
builder.Services.ConfigureDPoPTokensForScheme("token");
```

## Distributed Cache Requirement

DPoP validation uses `IDistributedCache` for nonce and replay detection. You must register a cache implementation:

- `AddDistributedMemoryCache()` — for development/single-instance
- `AddStackExchangeRedisCache()` — for production/multi-instance

Without a distributed cache, DPoP replay detection will fail.
