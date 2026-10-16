# Why the 8-hour limit keeps extending, and how to cap it

## Why
With server-side sessions, IdentityServer calls `SignInAsync` whenever the session's client list changes, for example when the user signs into an additional client. That re-issues the cookie and **resets its timer**, so the cookie expiration can extend beyond the configured lifetime (without server-side sessions the expiry is set once at login). Refresh-token use is also an activity signal that extends the session. Together, a user moving between clients and refreshing tokens never reaches the 8-hour mark.

## Hard cap

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
}).AddServerSideSessions();
```

Cookie lifetime alone is not enough because of the renewals above. On the client, combine:

- `UserSsoLifetime`: forces interactive re-authentication after N seconds regardless of cookie renewals.
- `AbsoluteRefreshTokenLifetime` with `RefreshTokenExpiration = TokenExpiration.Absolute`: caps refresh-token-driven session extension.

```csharp
new Client
{
    ClientId = "web.app",
    // ...
    AllowOfflineAccess = true,
    UserSsoLifetime = 8 * 3600,                    // re-authenticate after 8h
    AbsoluteRefreshTokenLifetime = 8 * 3600,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    CoordinateLifetimeWithUserSession = true
}
```

With ASP.NET Core Identity, the session lifetime comes from `ConfigureApplicationCookie(o => o.ExpireTimeSpan = TimeSpan.FromHours(8))` (default 14 days), not `CookieLifetime`.

## Result
After 8 hours from authentication, `UserSsoLifetime` forces a new interactive login on `web.app`, and refresh tokens expire absolutely at 8 hours so a refresh-token-driven session can't extend further. The client should handle refresh failure or implement back-channel logout.
