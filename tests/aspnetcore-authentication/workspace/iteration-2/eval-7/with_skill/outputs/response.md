# Fixing Large Authentication Cookie Size

## The Problem

When you use `SaveTokens = true` with the OIDC handler, the access token, refresh token, and ID token are all stored inside the authentication cookie. Combined with claims from the userinfo endpoint, this can easily push the cookie over the 4KB browser limit. When the cookie exceeds this limit, the browser silently truncates or drops it, causing authentication failures.

## Why SaveTokens = true Contributes

`SaveTokens = true` stores the following tokens in the authentication cookie:
- **Access token** — Can be large, especially JWT access tokens with many claims
- **Refresh token** — An opaque string, but still adds bytes
- **ID token** — Another JWT with identity claims
- **expires_at** — Token expiration timestamp

These tokens alone can consume 1-3KB of cookie space, leaving very little room for user claims.

## Solutions

### Solution 1: Use ITicketStore to Move the Auth Ticket Server-Side

Instead of storing the entire authentication ticket (claims + tokens) in the cookie, store it server-side and only keep a session key in the cookie:

```csharp
// Register a distributed cache (e.g., Redis)
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});

// Implement ITicketStore backed by IDistributedCache
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>();

// Wire the ITicketStore into the cookie handler
.AddCookie("Cookies", options =>
{
    options.SessionStore = app.Services.GetRequiredService<ITicketStore>();
});
```

With this approach, the cookie only holds a small session key (typically ~50 bytes). The full authentication ticket (with all claims and tokens) is stored in the distributed cache. `ITicketStore` is in the `Microsoft.AspNetCore.Authentication.Cookies` namespace — you must implement it yourself backed by `IDistributedCache` or another store.

### Solution 2: Filter Unnecessary Claims

Remove claims you don't need in the cookie using `ClaimActions.DeleteClaims`:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // Remove claims that aren't needed in the cookie
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr");
    
    // ... other options
});
```

Common candidates for removal:
- `sid` — Session ID (usually only needed server-side)
- `idp` — Identity provider name
- `auth_time` — When the user authenticated
- `amr` — Authentication methods used

### Solution 3: Use Duende IdentityServer Server-Side Sessions

If you're using Duende IdentityServer, server-side sessions can help manage session state on the IdentityServer side, reducing what needs to be stored in the client's cookie.

## Recommended Approach

For most applications, **combine Solution 1 and Solution 2**:
1. Filter unnecessary claims to reduce the ticket size
2. Use an `ITicketStore` to move the ticket server-side so the cookie only holds a session key

This eliminates the cookie size problem entirely while maintaining all functionality.
