# User.FindFirst("sub") Returns Null

## The Issue

The ASP.NET Core OIDC and JWT Bearer handlers automatically map JWT claim types to longer .NET claim type URIs. The `sub` claim from your ID token is being renamed to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

So when you call `User.FindFirst("sub")`, it returns null because the claim is stored under a different key.

## Fix

You can disable this automatic mapping:

```csharp
// On the OIDC handler
options.MapInboundClaims = false;

// Or on the JWT Bearer handler
options.MapInboundClaims = false;
```

After setting this, `User.FindFirst("sub")` will work correctly because the claim retains its original name from the token.

You should also set the name and role claim types so that `User.Identity.Name` and role-based authorization continue to work:

```csharp
options.TokenValidationParameters = new TokenValidationParameters
{
    NameClaimType = "name",
    RoleClaimType = "role"
};
```

This is a common pitfall when working with OpenID Connect - the default mapping silently renames claims, which can be confusing when you know the claim exists in the token but can't find it in code.
