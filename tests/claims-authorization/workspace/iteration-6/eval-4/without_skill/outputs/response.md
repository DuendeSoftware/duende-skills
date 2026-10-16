# Enriching the ClaimsPrincipal in the API

Use `IClaimsTransformation` (runs after authentication) or the `JwtBearerEvents.OnTokenValidated` event.

## IClaimsTransformation
```csharp
public class AppRoleClaimsTransformation(AppDbContext db, IMemoryCache cache) : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.Identity is not ClaimsIdentity { IsAuthenticated: true } identity) return principal;
        if (identity.HasClaim(c => c.Type == "app_roles_loaded")) return principal;

        var sub = principal.FindFirstValue("sub") ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (sub is null) return principal;

        var roles = await cache.GetOrCreateAsync($"roles:{sub}", async e =>
        {
            e.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await db.UserRoles.Where(r => r.Subject == sub).Select(r => r.Role).ToListAsync();
        });

        var clone = principal.Clone();
        var id = (ClaimsIdentity)clone.Identity!;
        foreach (var r in roles!) id.AddClaim(new Claim(id.RoleClaimType, r));
        id.AddClaim(new Claim("app_roles_loaded", "1"));
        return clone;
    }
}

builder.Services.AddScoped<IClaimsTransformation, AppRoleClaimsTransformation>();
```
Note: `TransformAsync` may run multiple times per request, so make it idempotent (marker claim) and cache lookups.

## Alternative: OnTokenValidated
```csharp
options.Events = new JwtBearerEvents
{
    OnTokenValidated = async ctx =>
    {
        var db = ctx.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
        // add claims to ctx.Principal.Identity as ClaimsIdentity
    }
};
```
This runs once per request, right after validation.

Remember `MapInboundClaims = false` and `RoleClaimType = "role"` if you use `[Authorize(Roles=...)]`. Alternatively use policy-based authorization with an `IAuthorizationHandler` that queries the DB directly.
