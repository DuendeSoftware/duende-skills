# Authentication Cookie Too Large — Solutions

## The Problem

Your authentication cookie exceeds the 4KB browser limit because of two factors:

1. **`SaveTokens = true`** stores the access token, refresh token, and ID token directly in the cookie. Access tokens can be large (especially JWTs with many claims), and refresh tokens add even more bulk.
2. **Claims from the userinfo endpoint** add additional data to the cookie's authentication ticket.

Combined, these easily push the cookie past the 4KB limit, causing browsers to silently truncate or reject it.

## Solutions

### Solution 1: Server-Side Ticket Store (ITicketStore)

Move the full authentication ticket out of the cookie and into a server-side store. The cookie then only holds a small session key/identifier.

```csharp
// Implement ITicketStore backed by IDistributedCache (e.g., Redis)
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>(); // Your custom implementation

.AddCookie("Cookies", options =>
{
    // Wire the ITicketStore so the cookie only holds a session key, not the full ticket
    options.SessionStore = app.Services.GetRequiredService<ITicketStore>();
});
```

`ITicketStore` (from `Microsoft.AspNetCore.Authentication.Cookies`) requires you to implement `StoreAsync`, `RenewAsync`, `RetrieveAsync`, and `RemoveAsync`. You can back it with `IDistributedCache`, a database, or any persistent store.

### Solution 2: Filter Unnecessary Claims

Remove claims you don't need from the cookie using `ClaimActions.DeleteClaims`:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // Remove claims that aren't needed in the cookie
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr");
});
```

Claims like `sid` (session ID), `idp` (identity provider), `auth_time`, and `amr` (authentication method) are often unnecessary in the client application and can safely be removed.

### Solution 3: Use Duende IdentityServer Server-Side Sessions

If you're using Duende IdentityServer, server-side sessions move session management to the server, dramatically reducing cookie size.

## Recommendation

For most applications, **Solution 1 (ITicketStore)** is the most effective because it caps the cookie size at a small session key regardless of how many tokens or claims exist. Combine it with **Solution 2** to keep the server-side ticket lean as well.
