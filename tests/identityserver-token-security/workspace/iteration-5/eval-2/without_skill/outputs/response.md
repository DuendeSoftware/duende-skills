# Validating DPoP proof tokens in your API

To validate DPoP-bound access tokens in an ASP.NET Core API against Duende IdentityServer, you combine standard JWT bearer authentication with Duende's DPoP extension.

## Packages

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

The `Duende.AspNetCore.Authentication.JwtBearer` package adds the DPoP proof-validation support on top of the built-in bearer handler.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidateAudience = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Enable DPoP proof validation for the "token" scheme
builder.Services.ConfigureDPoPTokensForScheme("token");

// DPoP needs somewhere to track proofs so they can't be replayed
builder.Services.AddDistributedMemoryCache(); // dev only; use Redis in production

builder.Services.AddAuthorization();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## What's happening

- **`AddJwtBearer("token", ...)`** sets up normal access-token validation against your IdentityServer authority. Restricting `ValidTypes` to `at+jwt` ensures only access tokens are accepted.
- **`ConfigureDPoPTokensForScheme("token")`** wires up the DPoP handler for that scheme. It reads the `DPoP` header, validates the proof JWT, and confirms the proof key matches the `cnf`/`jkt` value inside the access token, as well as checking the HTTP method and URL.
- **A distributed cache** is required so the server can remember which DPoP proofs it has already seen and reject replays. `AddDistributedMemoryCache` is fine locally, but for a multi-instance production deployment you should use a shared store such as Redis or SQL Server.

With this in place, an incoming request must present both a valid access token and a matching DPoP proof, or authentication fails.
