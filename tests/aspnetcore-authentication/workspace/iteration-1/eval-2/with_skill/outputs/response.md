# JWT Bearer Authentication for API

Here's the updated `Program.cs` with JWT Bearer authentication configured for your API:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api"; // Must match the ApiResource name in IdentityServer

        // CRITICAL: Disable Microsoft's JWT claim type mapping
        // Without this, 'sub' → long XML URI, 'name' → long XML URI, etc.
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            // Map Name and Role claims so User.Identity.Name and role-based auth work
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Authentication MUST come before Authorization
app.UseAuthentication();
app.UseAuthorization();

// Protect endpoints
app.MapGet("/", () => "Hello World!").RequireAuthorization();

app.Run();
```

## Key Configuration Points

1. **`MapInboundClaims = false`**: This is critical. Without it, the JWT handler silently remaps standard JWT claim types (`sub`, `name`, `role`) to verbose XML URIs like `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`. Setting this to `false` preserves the original claim names from the token.

2. **`NameClaimType = "name"` and `RoleClaimType = "role"`**: After disabling claim mapping, you need to tell ASP.NET Core which claim types to use for `User.Identity.Name` and role-based authorization (`User.IsInRole()`, `[Authorize(Roles = "...")]`). With standard OIDC tokens from IdentityServer, the correct values are `"name"` and `"role"`.

3. **`Audience = "catalog-api"`**: This ensures the API only accepts tokens specifically issued for it. The audience in the access token must match.

4. **Middleware ordering**: `UseAuthentication()` must come before `UseAuthorization()` so the user's identity is established before authorization policies are evaluated.
