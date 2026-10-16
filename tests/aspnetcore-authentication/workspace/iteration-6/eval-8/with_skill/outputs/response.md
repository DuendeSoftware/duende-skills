## Cause

The Microsoft OIDC/JWT handlers remap inbound JWT claim types to .NET/XML claim types by default (`MapInboundClaims = true`). `sub` becomes `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`, so `User.FindFirst("sub")` returns null even though the token contains it. (`name` and `email` and `role` are renamed likewise.)

## Fix

Disable mapping and tell ASP.NET Core which claims are name/role:

```csharp
// ❌ default: MapInboundClaims = true
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.MapInboundClaims = false;   // ✅
    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

// JWT Bearer: same
.AddJwtBearer("Bearer", options => options.MapInboundClaims = false);
```

After that, `User.FindFirst("sub")?.Value` works. The workaround of querying `ClaimTypes.NameIdentifier` also works, but turning mapping off is recommended.
