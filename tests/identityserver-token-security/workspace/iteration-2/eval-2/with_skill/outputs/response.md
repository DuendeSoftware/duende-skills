# Configuring API DPoP Validation

## Required Package

Install the Duende DPoP validation package:

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

This package extends the standard JWT Bearer handler with DPoP proof token processing and validation.

## API Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure JWT Bearer authentication for the 'token' scheme
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Enable DPoP validation for the 'token' scheme
// This is called on IServiceCollection, NOT inside the AddJwtBearer lambda
builder.Services.ConfigureDPoPTokensForScheme("token");

// DPoP replay detection requires a distributed cache
// Use in-memory for development only — use Redis or similar for production
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

## Key Details

### `ConfigureDPoPTokensForScheme("token")`

This is called on `builder.Services` (the `IServiceCollection`), **not** inside the `AddJwtBearer` lambda. It extends the authentication scheme to:

1. Accept the `DPoP` authorization scheme (instead of `Bearer`)
2. Validate the DPoP proof token from the `DPoP` HTTP header
3. Verify the `cnf` claim in the access token matches the DPoP proof's key thumbprint
4. Validate the HTTP method and URL match the request
5. Detect replay attacks using the distributed cache
6. Return appropriate `DPoP-Nonce` headers when nonce validation is enabled

### Distributed Cache

DPoP replay detection stores proof token `jti` values to prevent reuse. In production, use a durable distributed cache:

```csharp
// Production: use Redis
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-connection-string";
});
```

### ValidTypes

Setting `ValidTypes = new[] { "at+jwt" }` ensures the handler only accepts access tokens (with the `at+jwt` type header), not identity tokens or other JWT types.
