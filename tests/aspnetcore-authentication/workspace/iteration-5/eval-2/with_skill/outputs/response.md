Here's a `Program.cs` that validates JWT access tokens issued by your IdentityServer and makes `User.Identity.Name` and role-based authorization work correctly.

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api"; // must match the ApiResource name in IdentityServer

        // Do not remap inbound JWT claim types to the long XML/SOAP URIs
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",

            // Make User.Identity.Name and [Authorize(Roles = "...")] resolve from the JWT
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Authentication must run before authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", (HttpContext ctx) =>
        Results.Ok(new { user = ctx.User.Identity?.Name }))
    .RequireAuthorization();

app.Run();
```

### Why the claim settings matter

- **`MapInboundClaims = false`** — By default the JWT Bearer handler renames inbound claims to XML URIs (`name` → `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`, `role` → `http://schemas.microsoft.com/ws/2008/06/identity/claims/role`). Disabling the mapping preserves the short names your token actually carries.
- **`NameClaimType = "name"`** — Tells ASP.NET Core which claim populates `User.Identity.Name`. Without it (and with mapping off) `User.Identity.Name` would be `null`.
- **`RoleClaimType = "role"`** — Makes `User.IsInRole("...")`, `[Authorize(Roles = "...")]`, and role-based policies read the `role` claim from the token.
- **`Authority`** — The handler downloads discovery metadata and the signing keys from `https://identity.example.com/.well-known/openid-configuration`, so you don't hard-code keys.
- **`Audience` / `ValidAudience = "catalog-api"`** — Ensures the API only accepts tokens minted for it.

> Keep `UseAuthentication()` before `UseAuthorization()` so the authorization middleware sees the authenticated principal.
