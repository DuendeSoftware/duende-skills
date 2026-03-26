# Cookie Size Too Large

When `SaveTokens = true` and many claims come from the userinfo endpoint, the authentication cookie can exceed the 4KB browser limit. Here are the solutions:

## Understanding the Problem

`SaveTokens = true` stores the access token, refresh token, and ID token directly in the authentication cookie. Combined with claims from the userinfo endpoint, this can easily exceed the 4KB cookie size limit, causing silent authentication failures.

## Solution 1: Use ITicketStore (Server-Side Session)

Move the authentication ticket out of the cookie entirely. The cookie only holds a session key, while the full ticket (including tokens and claims) is stored server-side.

```csharp
// Implement ITicketStore backed by IDistributedCache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
builder.Services.AddSingleton<ITicketStore, RedisTicketStore>();

.AddCookie("Cookies", options =>
{
    options.SessionStore = serviceProvider.GetRequiredService<ITicketStore>();
});
```

## Solution 2: Filter Unnecessary Claims

Remove claims that aren't needed in the cookie using `ClaimActions.DeleteClaims`:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // Remove claims that are not needed by the app
    options.ClaimActions.DeleteClaims("sid", "idp", "auth_time", "amr");
});
```

## Solution 3: Duende IdentityServer Server-Side Sessions

If you're using Duende IdentityServer, enable server-side sessions which keep session data server-side and reduce cookie payload.

## Root Cause

`SaveTokens = true` stores access, refresh, and ID tokens in the cookie — each of which can be several hundred bytes to multiple kilobytes. This is the primary contributor to cookie bloat.
