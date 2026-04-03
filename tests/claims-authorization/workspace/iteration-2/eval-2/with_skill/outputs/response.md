# Fixing User.FindFirst("sub") Returning Null

## The Problem

This is a classic claim mapping issue. The `sub` claim IS in the token — you can see it at jwt.io — but the ASP.NET Core JWT bearer handler **renames** it during token validation.

## Root Cause: MapInboundClaims

By default, the JWT bearer handler has `MapInboundClaims = true`. This maps standard JWT/OIDC short claim names to long Microsoft WS-Federation XML namespace URIs:

| JWT Claim (in token) | Mapped To (in ClaimsPrincipal) |
|---|---|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

So `User.FindFirst("sub")` returns null because the claim is now stored under the long URI name. `User.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier")` would find it — but that's not what you want.

## The Fix

Set `MapInboundClaims = false` on the JWT bearer handler:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";

        // Keep standard OIDC short claim names — "sub", "name", "role", etc.
        options.MapInboundClaims = false;

        // Optionally set the name and role claim types so [Authorize(Roles = "...")] and
        // User.Identity.Name work correctly with the short names
        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name;   // "name"
        options.TokenValidationParameters.RoleClaimType = JwtClaimTypes.Role;   // "role"
    });
```

After this, `User.FindFirst("sub")` (or `User.FindFirst(JwtClaimTypes.Subject)`) will work as expected.

**The claim is NOT missing from the token.** It's being renamed by the handler. The fix is purely on the API side — no changes needed to IdentityServer or the token itself.
