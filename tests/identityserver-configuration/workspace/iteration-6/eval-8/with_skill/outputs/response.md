Issues:

1. **Missing `openid` scope.** The app must authenticate users; `openid` is mandatory for OIDC and returns `sub`. Add it (and the identity resources must be registered).
2. **Hardcoded plaintext secret.** `new Secret("super-secret-password")` is neither hashed nor safe in source control. Load a hash from configuration/vault (`new Secret(config["Clients:MyWebApp:SecretHash"])`) — or use `private_key_jwt`.
3. **Redirect URI trailing slash.** `.../signin-oidc/` won't match what ASP.NET Core sends (`/signin-oidc`), causing `invalid_redirect_uri`. Matching is exact.
4. **`AllowOfflineAccess = false`.** Refresh tokens require `true` (and the client requesting `offline_access`); otherwise none is issued silently. Add `offline_access` handling.
5. Missing `PostLogoutRedirectUris` for sign-out, and no explicit PKCE (default true, but make it explicit). Also consider `RefreshTokenUsage = OneTimeOnly`.

Fixed:
```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret(configuration["Clients:MyWebApp:SecretHash"]!) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.Email,
        "api1"
    }
}
```
Register matching resources: `IdentityResources.OpenId/Profile/Email` and `new ApiScope("api1")`.
