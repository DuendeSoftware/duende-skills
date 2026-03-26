# Why User.FindFirst("sub") Returns Null

## Root Cause

The JWT bearer handler in ASP.NET Core has a default behavior called **`MapInboundClaims`** that renames standard OIDC/JWT claim types to long Microsoft WS-Federation namespace URIs. When `MapInboundClaims` is `true` (the default), the handler maps:

| JWT Claim | Mapped To |
|-----------|-----------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

So the `sub` claim **is** in the token — you can see it at jwt.io — but after the handler processes it, it's stored in the `ClaimsPrincipal` under the long name `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`. That's why `User.FindFirst("sub")` returns null.

## Fix

Set `MapInboundClaims = false` on your JWT bearer handler:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        
        // Keep standard OIDC short claim names
        options.MapInboundClaims = false;
        
        // Optional: ensure User.Identity.Name and IsInRole() work correctly
        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name;   // "name"
        options.TokenValidationParameters.RoleClaimType = JwtClaimTypes.Role;   // "role"
    });
```

After this fix, `User.FindFirst("sub")` or `User.FindFirst(JwtClaimTypes.Subject)` will work as expected.

## Why This Happens

This is a legacy behavior from when ASP.NET used WS-Federation. The JWT handler maintains backward compatibility by mapping short JWT names to long XML namespace URIs. For modern OIDC/OAuth2 applications using IdentityServer, you always want `MapInboundClaims = false`.
