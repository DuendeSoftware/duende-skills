# Validating DPoP in your API

## Package
```
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```
(This builds on `Microsoft.AspNetCore.Authentication.JwtBearer`.)

## Setup

```csharp
builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false; // or set Audience
        options.MapInboundClaims = false;
    });

// Enable DPoP processing on the "token" scheme
builder.Services.ConfigureDPoPTokensForScheme("token");

builder.Services.AddAuthorization();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api", (ClaimsPrincipal user) => user.Identity!.Name)
   .RequireAuthorization();
```

`ConfigureDPoPTokensForScheme` makes the handler accept the `DPoP` authorization scheme (`Authorization: DPoP <token>`), validate the `DPoP` proof header (signature, `htm`, `htu`, `iat`, `ath` access-token hash), and verify the proof key matches the token's `cnf.jkt`. Plain bearer tokens continue to work for non-bound tokens unless you restrict them.

Optionally tune validation (`ProofTokenValidationParameters`, clock skew, nonce, replay cache — an `IDistributedCache` for multiple instances) via `ConfigureDPoPTokensForScheme("token", opt => { ... })`.
