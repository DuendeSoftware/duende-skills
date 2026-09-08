# Stale role claims on refreshed access tokens

This is expected default behavior, and there's a single client flag that fixes it.

## Default behavior

By default, `Client.UpdateAccessTokenClaimsOnRefresh` is **`false`**. On a refresh token redemption, IdentityServer does **not** re-run `IProfileService.GetProfileDataAsync` — it **reuses the original claims** captured when the token was first issued. The only profile-service method that runs on refresh is `IsActiveAsync` (to check the user is still allowed a token at all).

That's exactly your symptom: a user who lost a role still gets it in the refreshed access token, because the role claim set was frozen at initial issuance and simply copied forward.

## The fix

Set `UpdateAccessTokenClaimsOnRefresh = true` on the client. This causes `GetProfileDataAsync` to be **re-invoked** during refresh, so the refreshed access token reflects the user's **current** claims (including removed roles).

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

    AllowOfflineAccess = true,                 // enables refresh tokens
    UpdateAccessTokenClaimsOnRefresh = true    // re-run profile service on refresh
}
```

## Summary

| Setting | Refresh behavior |
|---|---|
| `UpdateAccessTokenClaimsOnRefresh = false` (default) | Original claims reused; only `IsActiveAsync` runs. Roles can go stale. |
| `UpdateAccessTokenClaimsOnRefresh = true` | `GetProfileDataAsync` re-runs; refreshed access-token claims reflect current state. |

Because `GetProfileDataAsync` will now run on every refresh, make sure any expensive lookups in your profile service are efficient or cached (keyed by subject + client), since refresh happens frequently. And remember: if you *deactivate* a user, also revoke their persisted grants — `IsActiveAsync` blocking issuance without revoking the refresh token just yields opaque token-request failures.
