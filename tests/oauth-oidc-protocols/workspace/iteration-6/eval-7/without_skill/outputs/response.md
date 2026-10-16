# Refresh token rotation

With rotation, each use of a refresh token returns a **new** refresh token and invalidates the old one. A stolen token can be used at most once; if the old one is replayed, the server can detect reuse. Limits the damage window of leakage.

Flow:
1. Login with `offline_access` → access token + refresh token RT1.
2. Access token expires → client posts `grant_type=refresh_token&refresh_token=RT1`.
3. Server returns new access token + RT2; RT1 is consumed.
4. Client must store RT2 (losing the response means being logged out).

In Duende IdentityServer this is `RefreshTokenUsage.OneTimeOnly`. (`ReUse` keeps the same handle.)

```csharp
new Client
{
    ClientId = "web",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1" }, // offline_access is enabled via AllowOfflineAccess

    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 1296000,  // 15 days
    AbsoluteRefreshTokenLifetime = 2592000, // 30 days
    UpdateAccessTokenClaimsOnRefresh = true,
    AccessTokenLifetime = 300
}
```
Client side request `offline_access` scope: `options.Scope.Add("offline_access"); options.SaveTokens = true;`. Use `Duende.AccessTokenManagement` to refresh automatically and persist the new refresh token.

Notes: `TokenUsage.OneTimeOnly` has a consumption concern with concurrent requests/network failure; IdentityServer offers a grace period via `RefreshTokenGracePeriodLifetime` (v7+) to tolerate retries. Use a persistent operational store (EF) so tokens survive restarts and can be revoked.
