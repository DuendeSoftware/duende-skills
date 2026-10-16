## What's going on

ASP.NET Core's JWT/OIDC handlers (via `JwtSecurityTokenHandler`) map inbound claim types by default: `sub` becomes `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` (`ClaimTypes.NameIdentifier`), `name` becomes `ClaimTypes.Name`, etc. So `User.FindFirst("sub")` returns null even though the ID token has it.

## Fixes

**Preferred – turn off mapping** so claims keep the names from the token:

```csharp
using System.IdentityModel.Tokens.Jwt;

JwtSecurityTokenHandler.DefaultMapInboundClaims = false;   // before building

builder.Services.AddAuthentication()
    .AddOpenIdConnect(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters.NameClaimType = "name";
        o.TokenValidationParameters.RoleClaimType = "role";
    });
// For JWT bearer: options.MapInboundClaims = false;
```

**Alternative** – keep mapping and look up `ClaimTypes.NameIdentifier`:

```csharp
var sub = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
```

You can inspect `User.Claims` to see which names are present.
