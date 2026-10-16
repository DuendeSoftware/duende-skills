# DPoP validation in an ASP.NET Core API

Use Duende's `Duende.AspNetCore.Authentication.JwtBearer` package.

```
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

```csharp
using Duende.AspNetCore.Authentication.JwtBearer.DPoP;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Enable DPoP validation for the "token" scheme
builder.Services.ConfigureDPoPTokensForScheme("token", opt =>
{
    opt.ValidationMode = ExpirationValidationMode.IssuedAt; // validate proof 'iat'
});

// Replay detection needs a cache
builder.Services.AddDistributedMemoryCache(); // use Redis etc. when scaled out

builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected" }));
app.Run();
```

Notes:
- The scheme name passed to `ConfigureDPoPTokensForScheme` must match the JWT scheme ("token").
- The handler checks the `cnf.jkt` confirmation claim matches the proof JWT key, checks the `htm`/`htu`, `iat`, and replay of `jti`.
- Clients send `Authorization: DPoP <token>` and a `DPoP` header.
- In a multi-instance deployment use a shared distributed cache so replay protection works across nodes.
- Behind proxies make sure the request scheme/host are correct (forwarded headers), otherwise `htu` mismatches.
