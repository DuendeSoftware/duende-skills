# Preventing the Authentication Cookie from Extending Indefinitely

## What's likely happening

The most common reason an authentication cookie keeps pushing its expiration forward is **sliding expiration**: when enabled, each request within the window re-issues the cookie with a fresh expiration, so an active user's cookie never actually reaches its intended end time. If you want a fixed 8-hour window, you generally start by turning sliding off and pinning the cookie lifetime.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
})
    .AddServerSideSessions();
```

## Capping refresh-token-driven sessions

Even with the cookie pinned, a client that holds refresh tokens can keep obtaining new access tokens and effectively stay signed in. To stop that, give the client an **absolute** refresh token lifetime so it can't slide:

```csharp
new Client
{
    ClientId = "web.app",
    // ...
    AllowOfflineAccess = true,

    AbsoluteRefreshTokenLifetime = 8 * 3600,            // 28800 seconds
    RefreshTokenExpiration = TokenExpiration.Absolute,  // do not slide
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
}
```

With `RefreshTokenExpiration = TokenExpiration.Absolute` and `AbsoluteRefreshTokenLifetime = 28800`, the refresh token expires exactly 8 hours after issuance and cannot be extended, so refresh-driven sessions are capped at 8 hours and the user must re-authenticate.

## Summary

- Turn off sliding expiration and set an 8-hour cookie lifetime so the cookie doesn't keep renewing.
- Set the client's refresh token to absolute expiration with an 8-hour lifetime so token refresh can't extend the session past the limit.

Together these force the user back through interactive login after roughly 8 hours.
