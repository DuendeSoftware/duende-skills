# User.FindFirst("sub") Returns Null

## The Problem

This is a common issue with ASP.NET Core's JWT bearer handler. By default, the handler maps JWT claim names to the longer Microsoft/WS-Federation XML namespace claim types. The `sub` claim gets renamed to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

So when you call `User.FindFirst("sub")`, it returns null because the claim is stored under the longer name.

## The Fix

You need to disable the inbound claim type mapping on your JWT bearer handler:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        options.MapInboundClaims = false;
    });
```

With `MapInboundClaims = false`, the handler preserves the original JWT claim names like `sub`, `name`, `email`, etc.

You may also want to update the `TokenValidationParameters` so that `User.Identity.Name` still works:

```csharp
options.TokenValidationParameters.NameClaimType = "name";
options.TokenValidationParameters.RoleClaimType = "role";
```

The claim is definitely in the token (you confirmed via jwt.io). It's just being renamed during deserialization.
