# User.FindFirst("sub") Returns Null

## The Problem

Your `User.FindFirst("sub")` returns `null` because the Microsoft OIDC/JWT handler is **silently renaming** your claims. This is one of the most common pitfalls in ASP.NET Core authentication.

By default, `MapInboundClaims` is `true`, which causes the handler to map JWT claim types to .NET XML-based claim types:

| JWT Claim | Gets Remapped To |
|-----------|-----------------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

So your `sub` claim exists, but under a different name. `User.FindFirst("sub")` returns null because the claim has been renamed to the verbose XML URI.

## The Fix

Disable inbound claim mapping and set the correct claim types:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.MapInboundClaims = false;  // Keep original claim names

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",   // User.Identity.Name uses "name" claim
        RoleClaimType = "role"    // User.IsInRole() uses "role" claim
    };
});
```

After this fix:
- `User.FindFirst("sub")` ✅ works
- `User.Identity.Name` ✅ uses the `name` claim
- `User.IsInRole("admin")` ✅ uses the `role` claim

This is a common pitfall where claims are silently renamed by the handler, causing confusing null results even though the claims clearly exist in the token.
