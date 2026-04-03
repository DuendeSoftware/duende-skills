# Handling Network Failures with One-Time Refresh Tokens

If you're using one-time (rotating) refresh tokens and experiencing failures when the network drops during refresh, you need to handle the case where the old token was consumed but the client didn't receive the new one.

## Approach

You could implement a custom token service that allows a recently-consumed token to be reused within a short grace window. Here's a general approach:

```csharp
public class GracePeriodRefreshTokenService
{
    private readonly TimeSpan _gracePeriod = TimeSpan.FromSeconds(30);
    
    public bool ShouldAcceptConsumedToken(DateTime? consumedAt)
    {
        if (consumedAt == null) return false;
        return DateTime.UtcNow - consumedAt.Value < _gracePeriod;
    }
}
```

## Client Configuration

Make sure the mobile_app client has refresh tokens enabled with one-time rotation:

```csharp
new Client
{
    ClientId = "mobile_app",
    ClientName = "Mobile Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,
    RedirectUris = { "myapp://callback" },
    PostLogoutRedirectUris = { "myapp://signout" },
    AllowedScopes = { "openid", "profile", "api1" },
    RequirePkce = true,
    
    AllowOfflineAccess = true,
    RefreshTokenRotation = TokenRotation.OneTime
}
```

## Important Considerations

- You need to make sure consumed tokens aren't immediately deleted from the database so your grace period logic can actually find them
- Consider adding a configuration option to keep consumed tokens for a short period
- Register your custom service in the DI container to override the default behavior

The exact implementation will depend on your version of IdentityServer and what extensibility points are available for customizing refresh token validation.
