# `User.FindFirst("sub")` returns null

The claim is in the token, but ASP.NET Core's JWT bearer handler **remaps inbound claim types** by default. `sub` is mapped to `ClaimTypes.NameIdentifier` (`http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`), and `name`, `role`, etc. are remapped similarly.

## Fix
```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;           // keep "sub", "name", "role" as-is
        options.TokenValidationParameters.NameClaimType = "name";
        options.TokenValidationParameters.RoleClaimType = "role";
    });
```
If you use the legacy handler globally:
```csharp
JwtSecurityTokenHandler.DefaultMapInboundClaims = false;
// or JsonWebTokenHandler.DefaultMapInboundClaims = false;
```

## Alternatives
- Keep the mapping and query `ClaimTypes.NameIdentifier`.
- Set `NameClaimType`/`RoleClaimType` so `User.Identity.Name` and `[Authorize(Roles=...)]` work.

Debug: `foreach (var c in User.Claims) Console.WriteLine($"{c.Type}={c.Value}");`
