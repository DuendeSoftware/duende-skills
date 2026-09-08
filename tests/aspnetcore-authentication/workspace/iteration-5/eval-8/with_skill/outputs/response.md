## What's going on

`User.FindFirst("sub")` returns `null` because the Microsoft OIDC/JWT handler **remaps inbound claim types** by default. When a token is processed, the handler runs the inbound claim type map, which renames the standard JWT claims to legacy WS-Security / SOAP XML URIs:

| JWT claim in the token | What it becomes in `User.Claims` |
|------------------------|----------------------------------|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |

So the claim **is** there — it's just stored under the long URI, not `"sub"`. That's why `FindFirst("sub")` finds nothing. It's a classic, silent pitfall: the handler renames your claims without any error, and your `"sub"` / `"role"` lookups quietly break.

You could work around it by looking up the verbose name:

```csharp
// works, but ugly and fragile
var sub = User.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier")?.Value;
// or
var sub = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
```

…but the right fix is to turn the mapping off.

## The fix — disable inbound claim mapping

Set `MapInboundClaims = false` on the handler so claims keep their original names, then tell ASP.NET Core which claims to use for `User.Identity.Name` and role checks:

```csharp
.AddOpenIdConnect("oidc", options =>   // same idea for .AddJwtBearer(...)
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";

    // ✅ Keep original JWT claim names (sub stays "sub", role stays "role")
    options.MapInboundClaims = false;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name", // User.Identity.Name reads the "name" claim
        RoleClaimType = "role"  // [Authorize(Roles=...)] / IsInRole read the "role" claim
    };
});
```

After this, `User.FindFirst("sub")` returns the subject id as expected, `User.Identity.Name` is populated from `name`, and role-based authorization works off the `role` claim.

> If you have several handlers, set `MapInboundClaims = false` on each one that processes tokens. (There's also a global switch, `JwtSecurityTokenHandler.DefaultMapInboundClaims = false` / `JsonWebTokenHandler.DefaultInboundClaimTypeMap.Clear()`, but per-handler is clearer and more explicit.)
