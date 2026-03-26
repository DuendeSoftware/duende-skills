# JWT Bearer Authentication Setup

Here's the configured `Program.cs` for JWT Bearer authentication:

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        // Disable claim type mapping to keep standard OIDC claim names
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

app.MapGet("/", () => "Hello World!");

app.Run();
```

## Key Configuration

- **`MapInboundClaims = false`** — Prevents the JWT handler from renaming `sub` to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`. Without this, `User.FindFirst("sub")` returns null.
- **`NameClaimType = "name"`** — Maps `User.Identity.Name` to the `name` claim from the JWT.
- **`RoleClaimType = "role"`** — Enables `User.IsInRole("admin")` and `[Authorize(Roles = "admin")]` to work with the `role` claim.
- **`Audience = "catalog-api"`** — Ensures the API only accepts tokens intended for it.
