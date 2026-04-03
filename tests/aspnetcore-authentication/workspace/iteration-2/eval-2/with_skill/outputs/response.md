# JWT Bearer Authentication for API

Here's the updated `Program.cs` with JWT Bearer authentication configured for your API:

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        // Prevent claim type mapping from JWT names to XML URIs
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!")
    .RequireAuthorization();

app.Run();
```

## Key Configuration Details

- **`Authority`** — Points to your IdentityServer instance. The JWT Bearer handler will fetch the discovery document from `https://identity.example.com/.well-known/openid-configuration` to resolve the JWKS endpoint for signature validation.
- **`Audience = "catalog-api"`** — The handler validates that the `aud` claim in the access token matches this value. This must correspond to the `ApiResource` name configured in IdentityServer.
- **`MapInboundClaims = false`** — Disables Microsoft's default claim type mapping. Without this, JWT claims like `sub` are remapped to long XML URIs (e.g., `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`), making `User.FindFirst("sub")` return null.
- **`NameClaimType = "name"`** — Tells ASP.NET Core to use the `name` claim for `User.Identity.Name`. Without this (and with `MapInboundClaims = false`), `User.Identity.Name` would be null because the default expects the XML URI claim type.
- **`RoleClaimType = "role"`** — Tells ASP.NET Core to use the `role` claim for `User.IsInRole()` and `[Authorize(Roles = "...")]` checks.
- **Middleware ordering** — `app.UseAuthentication()` is called before `app.UseAuthorization()` so the authorization middleware can inspect the authenticated identity.
