# Fixing User.FindFirst("sub") Returning Null

## The Problem

If you can see the `sub` claim in the JWT at jwt.io but `User.FindFirst("sub")` returns null in your API, the issue is most likely with the JWT bearer handler's claim mapping.

## Root Cause

The ASP.NET Core JWT bearer handler, by default, maps certain JWT claim types to their Microsoft equivalents. The `sub` claim gets mapped to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`.

So the claim is there, but under a different name.

## Fix

You can disable this mapping:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        options.MapInboundClaims = false;
    });
```

Setting `MapInboundClaims = false` keeps the original JWT claim names intact. After this, `User.FindFirst("sub")` will return the value you expect.

Alternatively, you could access the claim using the mapped name:
```csharp
User.FindFirst(ClaimTypes.NameIdentifier)
```

But disabling the mapping is generally the recommended approach when working with OIDC-compliant tokens.
