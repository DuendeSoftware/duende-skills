# Validating DPoP proof tokens in your API

## Package

Install the Duende DPoP extension for JWT bearer authentication:

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

This package provides the `ConfigureDPoPTokensForScheme` extension that layers DPoP proof validation on top of a standard JWT bearer scheme.

## Setup

The key point: configure your JWT bearer scheme as normal, then call `ConfigureDPoPTokensForScheme("token")` **on `builder.Services` (IServiceCollection)** — *not* inside the `AddJwtBearer` options lambda. DPoP also needs an `IDistributedCache` for replay detection.

```csharp
using Duende.AspNetCore.Authentication.JwtBearer; // ConfigureDPoPTokensForScheme

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";

        // We validate the audience via scope-based policies instead.
        options.TokenValidationParameters.ValidateAudience = false;

        // Keep JWT claim types as-is.
        options.MapInboundClaims = false;

        // Only accept access tokens (typ header "at+jwt").
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Layer DPoP proof processing/validation on the "token" scheme.
// NOTE: this is called on IServiceCollection, NOT inside AddJwtBearer.
builder.Services.ConfigureDPoPTokensForScheme("token");

// DPoP replay detection requires a distributed cache.
// In-memory is fine for development; use Redis / SQL Server / CosmosDB in production.
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

## Why each piece matters

- **`AddJwtBearer("token", ...)`** — validates the access token itself against the authority. `ValidTypes = ["at+jwt"]` ensures only real access tokens are accepted (not ID tokens or other JWTs).
- **`ConfigureDPoPTokensForScheme("token")`** — this is the DPoP-specific step. It hooks into the `"token"` scheme to read the `DPoP` request header, validate the proof JWT, confirm the proof key thumbprint matches the token's `cnf.jkt`, verify the HTTP method/URL, enforce the `DPoP` authorization scheme, and detect replays. It must be registered on `builder.Services`, not within the bearer options lambda.
- **`AddDistributedMemoryCache()`** — DPoP replay detection stores proof identifiers (`jti`) so a captured proof cannot be re-used. In-memory is development-only; use a durable, shared `IDistributedCache` (Redis, SQL Server, CosmosDB) in production so replay state is consistent across instances.

Once configured, the library handles the full DPoP validation pipeline: token validation, proof validation, `cnf` matching, method/URL binding, nonce management, clock-skew handling, and returning the correct `WWW-Authenticate` / error headers when validation fails.
