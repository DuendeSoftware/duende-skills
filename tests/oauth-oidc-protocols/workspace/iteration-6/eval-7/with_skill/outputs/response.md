# Refresh token rotation

Refresh tokens are long-lived credentials. With **rotation**, every refresh returns a *new* refresh token and invalidates the old one, so a leaked token works at most once and reuse is detectable.

```
POST /connect/token
grant_type=refresh_token&refresh_token=old_rt&client_id=web.app&client_secret=...
→ { access_token, refresh_token: new_rt, expires_in }
```
The client must persist `new_rt` and discard `old_rt`.

In Duende IdentityServer this is `RefreshTokenUsage = TokenUsage.OneTimeOnly`. **Set it explicitly: the default became `ReUse` in v7.0.** A refresh token is only issued when the `offline_access` scope is requested and allowed.

## Client configuration
```csharp
new Client
{
    ClientId = "web.app",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "api1" },
    AllowOfflineAccess = true,                      // permits the offline_access scope

    RefreshTokenUsage = TokenUsage.OneTimeOnly,    // rotation
    RefreshTokenExpiration = TokenExpiration.Sliding,
    SlidingRefreshTokenLifetime = 1296000,          // 15 days
    AbsoluteRefreshTokenLifetime = 2592000,         // 30 days
    UpdateAccessTokenClaimsOnRefresh = true,
    AccessTokenLifetime = 300
}
```

## Client app
```csharp
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app"; o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.Scope.Add("api1");
    o.Scope.Add("offline_access");   // required to receive a refresh token
    o.SaveTokens = true;
});
builder.Services.AddOpenIdConnectAccessTokenManagement(); // Duende.AccessTokenManagement
```
Token management refreshes automatically and stores the rotated refresh token.

## Practical notes
- Store refresh tokens server-side (in the auth cookie ticket/session store), never in browser JS.
- Use the persistent operational store (EF) so tokens survive restarts and are revocable; revoke via the revocation endpoint on logout.
- Rotation + concurrent requests can race; serialize refreshes (AccessTokenManagement does) and consider the refresh token grace period option to tolerate lost responses.
