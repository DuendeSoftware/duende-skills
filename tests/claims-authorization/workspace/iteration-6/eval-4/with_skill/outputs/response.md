# Adding DB roles to the principal in the API

Use `IClaimsTransformation` **in the API** (it runs after authentication, before authorization). Don't do this on the IdentityServer host: there it affects cookie auth, not token content.

```csharp
public sealed class AppRoleClaimsTransformation(AppDbContext db, IMemoryCache cache) : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var sub = principal.FindFirstValue(JwtClaimTypes.Subject);
        if (sub is null) return principal;

        // Idempotent: TransformAsync can run multiple times per request
        if (principal.Identities.Any(i => i.AuthenticationType == "AppRoles")) return principal;

        var roles = await cache.GetOrCreateAsync($"app-roles:{sub}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await db.UserRoles.Where(r => r.Subject == sub).Select(r => r.Role).ToListAsync();
        });

        // Add a NEW identity; don't mutate the existing one in place
        var identity = new ClaimsIdentity("AppRoles", JwtClaimTypes.Name, JwtClaimTypes.Role);
        foreach (var role in roles!)
            identity.AddClaim(new Claim(JwtClaimTypes.Role, role));

        principal.AddIdentity(identity);
        return principal;
    }
}
```

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        options.MapInboundClaims = false;   // keep "sub"
    });

builder.Services.AddMemoryCache();
builder.Services.AddTransient<IClaimsTransformation, AppRoleClaimsTransformation>();

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("Admins", p => p.RequireRole("admin"));
```

Points:
- `MapInboundClaims = false` is required, otherwise `sub` is remapped and your lookup fails.
- Create a new `ClaimsIdentity`; the principal may be reused/cached.
- Cache DB lookups, since transformation runs on every request.
- The roles stay out of the token and are always current (within the cache TTL).
