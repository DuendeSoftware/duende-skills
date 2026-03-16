# Configuring API DPoP Validation

To validate DPoP proof tokens in your API, you'll need a special package from Duende that extends the standard JWT bearer handler.

## Package

Install the **Duende.AspNetCore.Authentication.JwtBearer** NuGet package:

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## API Configuration

```csharp
// API Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };

        // Configure DPoP validation for this scheme
        options.ConfigureDPoPTokensForScheme("token");
    });

// DPoP needs a distributed cache for replay detection
builder.Services.AddDistributedMemoryCache(); // Use Redis in production

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/data", () => "Protected data")
    .RequireAuthorization();

app.Run();
```

## How It Works

The DPoP validation middleware:

1. Validates the JWT access token normally
2. Extracts and validates the DPoP proof from the `DPoP` HTTP header
3. Verifies the `cnf.jkt` in the access token matches the key in the DPoP proof
4. Checks the HTTP method and URL in the proof match the actual request
5. Uses the distributed cache for replay detection (stores proof `jti` values)

## Important Notes

- You need a distributed cache implementation (`IDistributedCache`). `AddDistributedMemoryCache()` is fine for development, but use Redis (`AddStackExchangeRedisCache`) or SQL Server in production.
- The `ValidTypes` check for `at+jwt` ensures only JWT access tokens (per RFC 9068) are accepted.
- DPoP automatically handles both `DPoP` and `Bearer` authorization schemes.
