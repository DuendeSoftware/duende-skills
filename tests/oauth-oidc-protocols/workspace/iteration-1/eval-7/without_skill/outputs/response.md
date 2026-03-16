# Refresh Token Rotation

## How It Works

Refresh token rotation means that each time a client uses a refresh token to get a new access token, the server also issues a new refresh token and invalidates the old one. This limits the window of opportunity if a refresh token is compromised.

## Configuration

Here's how to configure a client with refresh token rotation in IdentityServer:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    ClientSecrets = { new Secret("secret".Sha256()) },

    RedirectUris = { "https://app.example.com/callback" },

    AllowOfflineAccess = true,

    // Enable refresh token rotation
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    AllowedScopes =
    {
        "openid",
        "profile",
        "api1",
        "offline_access"
    }
};
```

## Key Points

- **`AllowOfflineAccess = true`** — Required to enable the `offline_access` scope
- **`RefreshTokenUsage = TokenUsage.OneTimeOnly`** — Each refresh token use invalidates the old one and returns a new one
- The client must request `offline_access` scope to receive refresh tokens
- With `OneTimeOnly`, if an old refresh token is reused (e.g., by an attacker), it will be rejected

## Token Exchange

When the client refreshes:
1. Client sends the refresh token to the token endpoint with `grant_type=refresh_token`
2. Server validates the token, issues new access + refresh tokens
3. The old refresh token is invalidated
