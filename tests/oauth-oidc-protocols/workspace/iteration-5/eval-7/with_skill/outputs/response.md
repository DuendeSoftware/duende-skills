# Refresh Token Rotation with `OneTimeOnly`

## How refresh token rotation works

A refresh token is a long-lived credential a client uses to obtain new access tokens without sending the user through login again. Because it's long-lived, it's a juicy target — if it leaks, an attacker can mint access tokens until it expires.

**Rotation** mitigates this. With rotation enabled (`RefreshTokenUsage = OneTimeOnly`):

1. The client exchanges its current refresh token at the token endpoint (`grant_type=refresh_token`).
2. IdentityServer returns a **new access token *and* a new refresh token**.
3. The **old refresh token is immediately invalidated** — it can never be used again.
4. The client stores the new refresh token and uses it next time.

```
POST /connect/token
grant_type=refresh_token&refresh_token=OLD_RT
        │
        ▼
{ access_token: ..., refresh_token: NEW_RT }   // OLD_RT now dead
```

**Why this matters:** if a refresh token is stolen and used, then either the attacker or the legitimate client will present an already-consumed token on the next refresh. That reuse of an invalidated token is a detectable signal of compromise, and the leaked token has a very short useful life because the next legitimate refresh rotates it away. Contrast this with `ReUse`, where the same refresh token keeps working for its whole lifetime — a stolen token stays usable much longer.

## Important version note

In **Duende IdentityServer v7.0 the default changed to `RefreshTokenUsage.ReUse`**. That means rotation is **no longer on by default** — you must set `OneTimeOnly` **explicitly** on the client to get rotation. Don't assume it's rotating just because you're issuing refresh tokens.

## Client configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var webAppClient = new Client
{
    ClientId = "web.app",
    ClientName = "Web Application",

    ClientSecrets = { new Secret("secret".Sha256()) },

    // Interactive flow
    AllowedGrantTypes = GrantTypes.Code, // authorization_code (+ PKCE by default)

    RequirePkce = true,
    RequireConsent = false,

    RedirectUris = { "https://web.app/signin-oidc" },
    PostLogoutRedirectUris = { "https://web.app/signout-callback-oidc" },

    // 1. Allow refresh tokens to be issued
    AllowOfflineAccess = true,

    // 2. Rotate the refresh token on every use (must be explicit since v7.0)
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    // Optional: sliding vs absolute lifetime
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 15 * 24 * 3600, // 15 days

    // 3. offline_access must be an allowed scope to request a refresh token
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.OfflineAccess, // "offline_access"
        "api1"
    }
};
```

### The three things that make it work

1. **`AllowOfflineAccess = true`** — without this the client cannot request the `offline_access` scope, and no refresh token is issued at all.
2. **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** — this is the switch that turns on rotation. Each refresh returns a new refresh token and kills the old one. (Set it explicitly — the v7.0 default is `ReUse`.)
3. **`offline_access` in `AllowedScopes`** — the client must be permitted to ask for `offline_access` (shown above via `StandardScopes.OfflineAccess`).

## Client side

The requesting client must actually **request the `offline_access` scope** to receive a refresh token:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("offline_access"); // ask for a refresh token
    options.SaveTokens = true;
});
```

Then use `Duende.AccessTokenManagement` to perform the rotation-aware refresh automatically and persist the rotated token (see the `token-management` skill).
