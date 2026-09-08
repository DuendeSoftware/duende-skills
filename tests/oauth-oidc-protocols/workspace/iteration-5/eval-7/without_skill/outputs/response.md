# Refresh Token Rotation in Duende IdentityServer

## What refresh token rotation is

A refresh token lets a client obtain new access tokens without forcing the user to log in again. Since it lives a long time, it's a sensitive credential. **Rotation** reduces the risk of a leaked refresh token.

With rotation, every time the client uses a refresh token:

1. It calls the token endpoint with `grant_type=refresh_token` and the current refresh token.
2. The server issues a new access token **and a new refresh token**.
3. The old refresh token is invalidated so it can't be used again.

This limits the window in which a stolen refresh token is useful, and if a token is reused after being rotated out, that's a strong sign something was compromised.

In Duende IdentityServer this behavior is controlled by the `RefreshTokenUsage` setting on the client:

- `TokenUsage.OneTimeOnly` — rotate: each refresh returns a new refresh token and invalidates the previous one.
- `TokenUsage.ReUse` — the same refresh token keeps working until it expires.

## Configuring the client

To use rotation with the `offline_access` scope, configure the client like this:

```csharp
var client = new Client
{
    ClientId = "web.app",
    ClientSecrets = { new Secret("secret".Sha256()) },

    AllowedGrantTypes = GrantTypes.Code,

    RedirectUris = { "https://web.app/signin-oidc" },

    // Allow issuing refresh tokens
    AllowOfflineAccess = true,

    // Rotate refresh tokens on each use
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    AllowedScopes =
    {
        "openid",
        "profile",
        "offline_access",
        "api1"
    }
};
```

The important pieces:

- **`AllowOfflineAccess = true`** enables the client to request the `offline_access` scope, which is what causes a refresh token to be issued.
- **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** turns on rotation.
- **`offline_access` in `AllowedScopes`** allows the client to actually request that scope.

## On the client application side

Your app must request the `offline_access` scope during login to receive a refresh token:

```csharp
options.Scope.Add("offline_access");
```

After that, when the access token expires, your app (or a token-management library) uses the refresh token to get a new one, and with `OneTimeOnly` it will also receive a replacement refresh token to store for next time.
