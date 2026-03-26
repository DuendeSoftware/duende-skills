# Configuring API-Side DPoP Validation

To validate DPoP proof tokens at the API, you need the `Duende.AspNetCore.Authentication.JwtBearer` NuGet package, JWT bearer authentication, DPoP configuration, and a distributed cache for replay detection.

## NuGet Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## API Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// JWT Bearer authentication with DPoP
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Extend the 'token' scheme with DPoP processing and validation
// IMPORTANT: This is called on IServiceCollection, NOT inside AddJwtBearer
builder.Services.ConfigureDPoPTokensForScheme("token");

// Distributed cache for DPoP replay detection
// Use Redis, SQL Server, or CosmosDB in production
builder.Services.AddDistributedMemoryCache(); // in-memory for development only

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/data", () => "Protected data")
    .RequireAuthorization();

app.Run();
```

## Key Configuration Points

### `ConfigureDPoPTokensForScheme`
This is an extension method from the `Duende.AspNetCore.Authentication.JwtBearer` package. It extends the JWT bearer handler to:
1. Accept the `DPoP` authorization scheme (in addition to `Bearer`)
2. Validate the DPoP proof JWT from the `DPoP` HTTP header
3. Verify the `cnf.jkt` claim in the access token matches the proof key
4. Check the HTTP method and URL in the proof match the actual request
5. Detect replay attacks using the distributed cache

**Important**: `ConfigureDPoPTokensForScheme` is called on `builder.Services` (IServiceCollection), **not** inside the `AddJwtBearer` lambda. This is a common mistake.

### Distributed Cache
DPoP replay detection requires `IDistributedCache`. Without it, an attacker could replay captured DPoP proofs. In production, use a durable distributed cache like Redis:

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
```

### ValidTypes
Setting `ValidTypes` to `["at+jwt"]` ensures the API only accepts JWT access tokens (per RFC 9068), rejecting identity tokens or other JWT types.
