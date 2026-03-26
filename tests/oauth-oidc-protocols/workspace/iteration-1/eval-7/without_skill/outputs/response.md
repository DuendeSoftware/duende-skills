# Refresh Token Rotation

## Configuration

To set up refresh token rotation:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,

    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://webapp.example.com/callback" },

    AllowedScopes =
    {
        "openid",
        "profile",
        "api1",
        "offline_access"
    }
}
```

## How It Works

With `OneTimeOnly`:
1. Client uses the refresh token to get a new access token
2. The server issues a new refresh token along with the new access token
3. The old refresh token is invalidated

This limits the damage if a refresh token is stolen, since it can only be used once.

## Key Settings

- `AllowOfflineAccess = true` — allows the client to request refresh tokens
- `RefreshTokenUsage = TokenUsage.OneTimeOnly` — enables rotation
- `offline_access` scope — must be requested by the client
