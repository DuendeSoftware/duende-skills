# User.FindFirst("sub") Returns Null

The issue is that the ASP.NET Core JWT/OIDC handler remaps claim types by default. The `sub` claim is being mapped to a different claim type.

By default, the handler maps standard JWT claims to Microsoft's XML namespace claim types. So `sub` becomes `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

## Fix

You can disable this mapping:

```csharp
options.MapInboundClaims = false;
```

Or you can use the mapped name:
```csharp
User.FindFirst(ClaimTypes.NameIdentifier)
```

The recommended approach is to set `MapInboundClaims = false` so claims keep their original JWT names. You should also set:

```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    NameClaimType = "name",
    RoleClaimType = "role"
};
```
