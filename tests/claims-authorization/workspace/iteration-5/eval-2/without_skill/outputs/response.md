# `User.FindFirst("sub")` returns null even though the token has `sub`

This is a classic ASP.NET Core claim-mapping gotcha, not a token problem. Since you can see `sub` at jwt.io, the token is fine — the claim just isn't stored under the key `"sub"` after the JWT bearer handler processes it.

## What's happening

The default `JwtSecurityTokenHandler` used by the JWT bearer middleware ships with an inbound claim type map (`DefaultInboundClaimTypeMap`) that rewrites well-known short JWT claim names into the older, long Microsoft/WS-Federation claim URIs. So `sub` gets rewritten to:

```
http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier
```

That means:

```csharp
User.FindFirst("sub");                                                          // null
User.FindFirst(ClaimTypes.NameIdentifier);                                       // found
User.FindFirst("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"); // found
```

The claim is there — it's just under a different type name.

## Fix

Disable inbound claim mapping so the handler preserves the original short names:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://your-identityserver";
        options.Audience = "your-api";

        // Keep the original OIDC claim names ("sub", "name", "role", ...)
        options.MapInboundClaims = false;
    });
```

After this, `User.FindFirst("sub")` returns the value as expected.

If you'd rather not disable the whole map globally you could also clear just that one mapping:

```csharp
JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Remove("sub");
```

but setting `MapInboundClaims = false` is the cleaner, recommended approach and keeps all your claim names consistent with what's actually in the token.
