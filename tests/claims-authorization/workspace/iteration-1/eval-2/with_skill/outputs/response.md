# Why User.FindFirst("sub") Returns Null

## Root Cause: MapInboundClaims

The issue is the JWT bearer handler's `MapInboundClaims` behavior. By default, the ASP.NET Core JWT bearer handler maps short OIDC/JWT claim names to the long Microsoft WS-Federation XML namespace URIs. So `sub` gets silently renamed to:

```
http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier
```

This means `User.FindFirst("sub")` returns `null` — the claim exists, but under the long URI name instead.

The claim **is** in the token (you confirmed this at jwt.io). It's not missing — it's been renamed during deserialization.

## The Fix

Set `MapInboundClaims = false` on your JWT bearer handler configuration:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        
        // Keep standard OIDC short claim names (sub, name, email, etc.)
        options.MapInboundClaims = false;
        
        // Also set NameClaimType and RoleClaimType so User.Identity.Name 
        // and [Authorize(Roles = "...")] work correctly with the short names
        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name;   // "name"
        options.TokenValidationParameters.RoleClaimType = JwtClaimTypes.Role;   // "role"
    });
```

## Claim Name Mapping Reference

| JWT / OIDC short name (`JwtClaimTypes`) | Microsoft long name (`ClaimTypes`) |
|---|---|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

After applying the fix, `User.FindFirst("sub")` (or `User.FindFirst(JwtClaimTypes.Subject)`) will work correctly and return the subject claim value.
