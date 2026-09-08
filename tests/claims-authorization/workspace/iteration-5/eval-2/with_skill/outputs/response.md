# Why `User.FindFirst("sub")` returns null

The claim **is** in your token — you confirmed that at jwt.io. The problem is on the **consuming side**: the JWT bearer handler is renaming the claim during validation, so it's no longer stored under the key `"sub"`.

## Root cause: `MapInboundClaims`

By default the JWT bearer handler (via the underlying `JwtSecurityTokenHandler`) applies a legacy WS-Federation/SOAP claim-type map. That map silently **renames short OIDC claim names to long Microsoft XML namespace URIs**. In particular:

| Token claim | Stored in `ClaimsPrincipal` as |
|---|---|
| `sub` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` |
| `name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `role` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

So after validation, `User.FindFirst("sub")` returns `null`, but this works:

```csharp
User.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier");
```

That's why it looks "missing" even though it's clearly present in the raw JWT.

## The fix: turn off inbound claim mapping

Set `MapInboundClaims = false` on the JWT bearer handler so the handler keeps the original short OIDC claim names:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience  = "my_api";

        // Keep "sub", "name", "role" as-is — do not rename to WS-Federation URIs
        options.MapInboundClaims = false;

        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name; // "name"
        options.TokenValidationParameters.RoleClaimType = JwtClaimTypes.Role; // "role"
    });
```

`JwtClaimTypes` (from `Duende.IdentityModel` / `IdentityModel`) gives you the correct short constants — e.g. `JwtClaimTypes.Subject == "sub"` — so prefer:

```csharp
var sub = User.FindFirst(JwtClaimTypes.Subject)?.Value;   // now works
```

## Summary

- Nothing is wrong with the token; `sub` is present.
- The JWT bearer handler's default `MapInboundClaims = true` renamed `sub` to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.
- Set `options.MapInboundClaims = false` (and optionally `NameClaimType`/`RoleClaimType`) so `User.FindFirst(JwtClaimTypes.Subject)` / `User.FindFirst("sub")` resolve correctly.
