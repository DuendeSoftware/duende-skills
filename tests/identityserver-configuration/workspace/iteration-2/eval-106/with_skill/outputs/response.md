# Refresh Token Configuration for Mobile App Client

Here's how to configure a mobile app client with the specified refresh token behavior in Duende IdentityServer.

## Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("api1", "Main API")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "mobile.app",
            ClientName = "Mobile Application",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false, // Public client (mobile)

            RedirectUris = { "myapp://callback" },
            PostLogoutRedirectUris = { "myapp://signout-callback" },

            // Enable refresh tokens
            AllowOfflineAccess = true,

            // One-time use: rotate the refresh token on each use
            RefreshTokenUsage = TokenUsage.OneTimeOnly,

            // Absolute lifetime of 7 days (in seconds)
            AbsoluteRefreshTokenLifetime = 604800, // 7 * 24 * 60 * 60

            // Sliding window of 1 day (in seconds)
            SlidingRefreshTokenLifetime = 86400, // 1 * 24 * 60 * 60

            // Use sliding expiration — token is renewed within the sliding window
            RefreshTokenExpiration = TokenExpiration.Sliding,

            // Update claims in the access token on each refresh
            UpdateAccessTokenClaimsOnRefresh = true,

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "api1"
            }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Refresh Token Settings Explained

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowOfflineAccess` | `true` | Enables the `offline_access` scope, which triggers refresh token issuance |
| `RefreshTokenUsage` | `TokenUsage.OneTimeOnly` | Each time the refresh token is used, a new one is issued and the old one is invalidated. This prevents replay attacks. |
| `AbsoluteRefreshTokenLifetime` | `604800` (7 days) | The absolute maximum lifetime of the refresh token regardless of sliding renewal. After 7 days, the user must re-authenticate. |
| `SlidingRefreshTokenLifetime` | `86400` (1 day) | The refresh token's lifetime is extended by 1 day each time it is used, up to the absolute maximum. |
| `RefreshTokenExpiration` | `TokenExpiration.Sliding` | Enables the sliding window behavior. Without this, only the absolute lifetime applies. |
| `UpdateAccessTokenClaimsOnRefresh` | `true` | When a refresh token is used to get a new access token, the claims are re-evaluated from the user profile. This ensures claims stay up-to-date (e.g., if a user's roles change). |
