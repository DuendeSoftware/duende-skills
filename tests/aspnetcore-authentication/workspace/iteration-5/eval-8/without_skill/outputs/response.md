## Why `sub` is `null`

The claim is in the token — but the ASP.NET Core OIDC/JWT handler **renamed it** before it reached `User.Claims`. By default the handler applies an inbound claim-type map that translates short JWT claim names into long legacy XML (WS-Security/SOAP) URIs. In particular:

- `sub` → `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`
- `name` → `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`
- `role` → `http://schemas.microsoft.com/ws/2008/06/identity/claims/role`

So when you call `User.FindFirst("sub")`, there's no claim literally named `sub` anymore — it's under the `nameidentifier` URI. This silent renaming is a very common gotcha; nothing errors, your lookups just return `null`.

You *could* read it via the mapped name:

```csharp
var sub = User.FindFirst(ClaimTypes.NameIdentifier)?.Value; // the mapped "sub"
```

But the cleaner fix is to stop the mapping.

## The fix

Disable inbound claim mapping and explicitly set the name/role claim types:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    // ...

    // Stop renaming inbound claims to XML URIs
    options.MapInboundClaims = false;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});
```

For a JWT Bearer API it's the same:

```csharp
.AddJwtBearer(options =>
{
    options.MapInboundClaims = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});
```

With `MapInboundClaims = false`, claims keep their original names, so `User.FindFirst("sub")` returns the subject id. Setting `NameClaimType`/`RoleClaimType` ensures `User.Identity.Name` and role-based authorization still resolve correctly against the `name` and `role` claims.

(If you prefer a global switch, you can clear the static map with `JsonWebTokenHandler.DefaultInboundClaimTypeMap.Clear();` at startup, but doing it per-handler is more explicit.)
