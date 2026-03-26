# Fixing User.FindFirst("sub") Returning Null

## The Problem

The issue is that ASP.NET Core's JWT bearer handler remaps JWT claim types by default. The `sub` claim in the JWT gets renamed to the long Microsoft namespace URI `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

So `User.FindFirst("sub")` returns null because the claim is stored under a different name in the ClaimsPrincipal.

## The Fix

Disable the claim mapping on the JWT bearer handler:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        options.MapInboundClaims = false;
    });
```

With `MapInboundClaims = false`, the JWT handler will keep the original claim names from the token. Now `User.FindFirst("sub")` will work correctly.

You might also want to set the name and role claim types:

```csharp
options.TokenValidationParameters.NameClaimType = "name";
options.TokenValidationParameters.RoleClaimType = "role";
```
