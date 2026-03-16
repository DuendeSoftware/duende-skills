# Configuring API DPoP Proof Token Validation

To validate DPoP proof tokens in your API, you need the **Duende.AspNetCore.Authentication.JwtBearer** NuGet package, which extends the standard JWT bearer handler with DPoP processing.

## Install the Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## API Configuration

```csharp
// API Program.cs
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

// Configure JWT bearer authentication
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Extend the 'token' scheme with DPoP processing and validation
// IMPORTANT: This is called on builder.Services (IServiceCollection), NOT inside AddJwtBearer
builder.Services.ConfigureDPoPTokensForScheme("token");

// DPoP replay detection requires a distributed cache
// Use in-memory for development only; use Redis, SQL Server, or CosmosDB in production
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/protected", () => "Hello from protected API")
    .RequireAuthorization();

app.Run();
```

## How It Works

`ConfigureDPoPTokensForScheme("token")` registers middleware that:

1. Validates the access token normally via the JWT bearer handler.
2. Extracts the DPoP proof token from the `DPoP` HTTP request header.
3. Validates the JWT format and signature of the proof token.
4. Verifies the `cnf.jkt` claim in the access token matches the public key in the DPoP proof.
5. Validates the HTTP method and URL in the proof match the actual request.
6. Checks for replay attacks using the distributed cache (stores `jti` values).
7. Manages nonce generation and validation.
8. Handles clock skew between the client and API.
9. Returns appropriate `WWW-Authenticate` error response headers when validation fails.

## Key Points

- `ConfigureDPoPTokensForScheme` is called on `builder.Services` (the `IServiceCollection`), **not** inside the `AddJwtBearer` configuration lambda. This is a common mistake.
- The `IDistributedCache` is critical — without it, DPoP replay detection doesn't work. In production, use a durable distributed cache like Redis (`AddStackExchangeRedisCache`) or SQL Server (`AddDistributedSqlServerCache`).
- `ValidTypes = new[] { "at+jwt" }` ensures only JWT access tokens (per RFC 9068) are accepted.
- The API automatically handles both `DPoP` and `Bearer` authorization schemes when DPoP is not required by the client. If the client requires DPoP (`RequireDPoP = true`), only `DPoP` scheme tokens are issued.
