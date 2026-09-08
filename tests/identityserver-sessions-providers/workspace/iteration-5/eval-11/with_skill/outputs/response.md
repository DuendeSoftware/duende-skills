# Why the Cookie Keeps Extending — and How to Cap It

## Why this happens

With **server-side sessions**, IdentityServer calls `SignInAsync` **whenever the session's client list changes** — for example, each time the user signs into an *additional* client, that client is added to the session's tracked-client list, IdentityServer re-issues the authentication cookie, and the cookie's expiration timer is **reset**. So a user who keeps signing into new clients (or re-visiting existing ones that touch the session) effectively rolls their cookie forward indefinitely and never has to re-authenticate.

This is different from the **without-server-side-sessions** behavior, where the cookie expiration is set **once at login** and simply counts down. The re-issue-on-client-list-change is what defeats your intended 8-hour limit.

Note that `CookieSlidingExpiration = false` alone does **not** fix this — it stops time-based sliding, but the re-issue on client-list changes still resets the cookie.

## The fix: enforce a hard 8-hour cap

Cap it at the **client** level so it forces interactive re-authentication regardless of cookie renewals, and cap refresh-token-driven extension too.

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("WebAppSecret".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
    AllowOfflineAccess = true,
    AllowedCorsOrigins = { "https://app.example.com" },

    // (1) Hard SSO cap: forces INTERACTIVE re-auth after 8h, no matter how many
    //     times the cookie is re-issued by SignInAsync.
    UserSsoLifetime = 8 * 3600,   // 28800 seconds

    // (2) Cap refresh-token-driven session extension so a long-lived refresh
    //     token can't keep the session alive past 8h.
    AbsoluteRefreshTokenLifetime = 8 * 3600,               // 28800 seconds
    RefreshTokenExpiration = TokenExpiration.Absolute,     // absolute, not sliding
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
}
```

## Why both settings

- **`UserSsoLifetime = 28800`** — this is the key setting. It ignores cookie renewals: once the user's SSO session is 8 hours old, IdentityServer requires a fresh interactive login for `web.app`. This directly counters the `SignInAsync` cookie re-issue.
- **`AbsoluteRefreshTokenLifetime = 28800` + `RefreshTokenExpiration = TokenExpiration.Absolute`** — without this, a refresh-token-driven client could keep obtaining new tokens (and, with lifetime coordination, keep the session warm) beyond 8 hours. `Absolute` expiration means the refresh token dies 8 hours after issuance and cannot slide, so refresh-driven sessions are also hard-capped at 8 hours.

Together they guarantee an absolute 8-hour ceiling for `web.app`: interactive sessions are forced to re-auth via `UserSsoLifetime`, and refresh-token sessions are forced to re-auth when the absolute refresh token lifetime elapses.
