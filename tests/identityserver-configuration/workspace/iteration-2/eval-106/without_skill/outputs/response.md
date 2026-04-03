# Configuring Refresh Tokens for a Mobile Client

Here's how to set up refresh token behavior for your mobile app client with the requirements you specified.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("api1")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "mobile.app",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RequirePkce = true,

            RedirectUris = { "myapp://callback" },

            // Enable refresh tokens
            AllowOfflineAccess = true,

            // Rotate on each use
            RefreshTokenUsage = TokenUsage.OneTimeOnly,

            // 7 days absolute lifetime
            AbsoluteRefreshTokenLifetime = 604800,

            // 1 day sliding window
            SlidingRefreshTokenLifetime = 86400,
            RefreshTokenExpiration = TokenExpiration.Sliding,

            // Update claims on refresh
            UpdateAccessTokenClaimsOnRefresh = true,

            AllowedScopes = { "openid", "profile", "api1" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Explanation

- **AllowOfflineAccess = true**: This enables the client to request the `offline_access` scope, which triggers refresh token issuance.
- **RefreshTokenUsage = TokenUsage.OneTimeOnly**: Each time the refresh token is used, a new one is issued. The old token becomes invalid.
- **AbsoluteRefreshTokenLifetime = 604800**: The token expires after 7 days (604800 seconds) regardless of activity.
- **SlidingRefreshTokenLifetime = 86400**: The token gets extended by 1 day each time it's used, but won't exceed the absolute lifetime.
- **RefreshTokenExpiration = TokenExpiration.Sliding**: Enables the sliding window behavior.
- **UpdateAccessTokenClaimsOnRefresh = true**: When refreshing, the claims in the new access token are updated from the current user profile.
