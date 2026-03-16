# Configuring DPoP (Demonstration of Proof-of-Possession) for Your API

DPoP binds access tokens to a client's cryptographic key, preventing token theft and replay. Here's how to configure it correctly.

## Step 1: Add the NuGet Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## Step 2: Configure DPoP Validation

The critical detail: `ConfigureDPoPTokensForScheme` is called on `IServiceCollection` (i.e., `builder.Services`), **NOT** inside the `AddJwtBearer` options lambda.

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// DPoP replay detection requires a distributed cache
builder.Services.AddDistributedMemoryCache(); // Use Redis/SQL in production

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        
        // Validate the at+jwt type header to prevent JWT confusion attacks
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Configure DPoP on the service collection, NOT inside AddJwtBearer
builder.Services.ConfigureDPoPTokensForScheme("token");

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Common Mistake: Wrong Location for DPoP Configuration

```csharp
// ❌ WRONG: ConfigureDPoPTokensForScheme inside AddJwtBearer lambda
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.ConfigureDPoPTokensForScheme("token"); // This is NOT valid
    });

// ✅ CORRECT: ConfigureDPoPTokensForScheme on IServiceCollection
builder.Services.ConfigureDPoPTokensForScheme("token");
```

## How DPoP Validation Works

When `ConfigureDPoPTokensForScheme` is configured:

1. The middleware looks for a `DPoP` HTTP header containing a proof JWT
2. It validates the proof JWT's signature against the key in the `jkt` (JWK thumbprint) claim from the access token's `cnf` claim
3. It verifies the proof is bound to the correct HTTP method and URL
4. It uses `IDistributedCache` for nonce/replay detection — this is why you must register a distributed cache

## Distributed Cache Requirement

DPoP nonce validation requires `IDistributedCache`:

- **Development**: `AddDistributedMemoryCache()` is fine
- **Production**: Use a shared cache like Redis (`AddStackExchangeRedisCache()`) or SQL Server, especially with multiple API instances

Without a distributed cache, DPoP replay detection won't work, and you'll get runtime errors.
