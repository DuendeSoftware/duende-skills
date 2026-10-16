# Cookie lifetime keeps extending

## Why
Each interactive sign-in at IdentityServer (including the one triggered when a second client such as another app requests authorization with `prompt` or re-auth) calls `SignInAsync` again, which issues a fresh authentication cookie/session ticket with a new `IssuedUtc` and new `ExpiresUtc`. With sliding expiration, requests also renew the session. So the 8-hour window restarts and the user is never forced to re-authenticate.

## Fix
1. Make the IdentityServer cookie absolute:

```csharp
options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
options.Authentication.CookieSlidingExpiration = false;
```

2. Enforce a per-client SSO cap so that tokens/authorization relative to the original authentication time force login:

```csharp
new Client
{
    ClientId = "web.app",
    UserSsoLifetime = 8 * 3600,                 // seconds since auth_time, forces re-login after 8h
    CoordinateLifetimeWithUserSession = true,   // refresh tokens die with the user session
    ...
}
```

`UserSsoLifetime` compares against `auth_time`; when exceeded, authorize requests trigger interactive login (`prompt=login` semantics). `CoordinateLifetimeWithUserSession = true` ties refresh token lifetime to the server-side session, so refresh-driven sessions can't outlive it.

3. Keep `AddServerSideSessions()` on so the session can be expired server-side and expiry triggers cleanup/back-channel logout (`ExpiredSessionsTriggerBackchannelLogout = true`).

Also ensure the client app's own cookie uses non-sliding 8 hours, and `AccessTokenLifetime` is short.
