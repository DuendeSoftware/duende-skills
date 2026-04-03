# Adding DPoP (Demonstration of Proof-of-Possession) Support

DPoP binds an access token to a specific client's cryptographic key, preventing token theft and replay attacks.

## 1. Install the Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## 2. Configure DPoP in Program.cs

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// DPoP replay detection requires a distributed cache
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Validate at+jwt type header
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// IMPORTANT: ConfigureDPoPTokensForScheme is called on IServiceCollection,
// NOT inside the AddJwtBearer options lambda.
builder.Services.ConfigureDPoPTokensForScheme("token");

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## Key Points

- **`ConfigureDPoPTokensForScheme` is called on `builder.Services` (IServiceCollection)**, not inside the `AddJwtBearer` lambda. This is a common mistake.
- **A distributed cache is required** for DPoP nonce/replay detection. `AddDistributedMemoryCache()` works for development; use Redis or SQL Server in production for multi-node deployments.
- The DPoP validation:
  1. Validates the `DPoP` proof JWT in the request header
  2. Confirms the `jkt` (JWK thumbprint) in the access token's `cnf` claim matches the proof key
  3. Verifies the proof is bound to the correct HTTP method and URL
  4. Uses `IDistributedCache` for nonce/replay detection
