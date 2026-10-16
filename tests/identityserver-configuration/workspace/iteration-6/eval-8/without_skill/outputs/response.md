Problems:
1. **Missing `openid` scope**: a code-flow OIDC client must include `openid` to authenticate users.
2. **Plaintext secret**: `new Secret("...")` stores the secret as-is; use `.Sha256()` and load the value from configuration/vault. Also "super-secret-password" is weak.
3. **Redirect URI trailing slash**: `https://app.example.com/signin-oidc/` won't match the default `/signin-oidc`; remove the slash.
4. **`AllowOfflineAccess = false`**: refresh tokens need `true` (plus `offline_access` scope requested by the client).
5. **No PostLogoutRedirectUris** (if logout redirect is needed) and PKCE should be explicit.

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret(configuration["Clients:MyWebApp:SecretHash"]) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "api1" },
    AllowOfflineAccess = true
}
```
Also make sure the identity resources for openid/profile/email and the `api1` ApiScope are registered.
