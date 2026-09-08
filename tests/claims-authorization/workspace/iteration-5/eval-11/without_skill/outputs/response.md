# Refreshed access tokens carry stale role claims

This is a known IdentityServer default: when a refresh token is redeemed, the new access token is issued with the **same claims that were captured originally**, rather than freshly computed ones. So if a user lost a role after the initial login, the refreshed token still shows the old role.

## The fix

Set `UpdateAccessTokenClaimsOnRefresh = true` on the client. With this enabled, IdentityServer re-runs your `IProfileService` when issuing the refreshed access token, so the claims reflect the user's current state.

```csharp
new Client
{
    ClientId = "interactive",
    ClientName = "Interactive Client",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "api1" },

    AllowOfflineAccess = true,                  // refresh tokens
    UpdateAccessTokenClaimsOnRefresh = true     // recompute claims on refresh
}
```

## Why the default behaves this way

By default this flag is off, which is a performance optimization — reusing the already-computed claims avoids hitting your profile service (and any database it queries) on every refresh. The tradeoff is exactly what you've hit: the claims can become stale between the initial issuance and the refresh.

## Notes

- Turning this on means your profile service runs on every refresh, so keep its work cheap or add caching if it does expensive lookups.
- For immediate revocation (not just "eventually consistent on next refresh"), you'd also want to revoke the user's refresh token / persisted grants when you strip their role, otherwise they keep a valid token until it expires.
- Short access token lifetimes also reduce the staleness window regardless of this setting.
