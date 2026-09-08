Here's a `Program.cs` for JWT Bearer authentication on your API.

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        // Keep the original claim names instead of the long XML/SOAP URIs
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            ValidateLifetime = true,

            // So User.Identity.Name and role checks work
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.MapGet("/secure", (HttpContext ctx) => $"Hi {ctx.User.Identity?.Name}")
    .RequireAuthorization();

app.Run();
```

### Explanation

- **`Authority`** points the handler at your IdentityServer. It fetches the OpenID Connect discovery document and the JWKS keys automatically, so token signatures are validated without you managing keys.
- **`Audience` / `ValidAudience`** is set to `catalog-api` so tokens issued for other resources are rejected.
- **`MapInboundClaims = false`** stops the handler from translating claim types like `name` and `role` into the `http://schemas.xmlsoap.org/...` URIs. This is what usually breaks `User.Identity.Name` and role checks.
- **`NameClaimType = "name"`** and **`RoleClaimType = "role"`** tell ASP.NET Core which claims back `User.Identity.Name` and `User.IsInRole(...)` / `[Authorize(Roles=...)]`.
- **Middleware order**: `UseAuthentication()` before `UseAuthorization()`.

That combination gives you working `User.Identity.Name` and role-based authorization out of the box.
