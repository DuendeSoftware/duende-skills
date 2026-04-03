# Refresh Token Rotation

## How It Works

Refresh token rotation means that each time a client uses a refresh token, the server issues a new refresh token and invalidates the old one. This limits the window of opportunity for an attacker who steals a refresh token.

The flow:
1. Client sends `refresh_token=RT1` to the token endpoint
2. Server validates RT1, issues new access token + `refresh_token=RT2`
3. RT1 is now invalid
4. Next time, client uses RT2, gets RT3, and so on

## Configuration

Here's how to configure a client with refresh token rotation:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    
    ClientSecrets = { new Secret("webapp-secret".Sha256()) },
    
    // Allow the offline_access scope
    AllowOfflineAccess = true,
    
    // Use one-time refresh tokens (rotation)
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    
    AllowedScopes =
    {
        "openid",
        "profile",
        "api1",
        "offline_access"
    },
    
    RedirectUris = { "https://myapp.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://myapp.example.com/signout-callback-oidc" }
}
```

## Key Properties

- `AllowOfflineAccess = true` - Enables the client to request `offline_access` scope which triggers refresh token issuance
- `RefreshTokenUsage = TokenUsage.OneTimeOnly` - Each refresh returns a new refresh token
- `AllowedScopes` must include `offline_access`

## Client Side

Request the `offline_access` scope:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "webapp-secret";
    options.ResponseType = "code";
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});
```
