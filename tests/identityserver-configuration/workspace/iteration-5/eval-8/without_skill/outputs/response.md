# Fixing the Client Configuration

The client has four functional problems and one security smell. Corrected version first, then explanations.

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,

    // Store the SHA-256 hash, and don't hardcode it
    ClientSecrets = { new Secret(builder.Configuration["MyWebApp:Secret"].Sha256()) },

    // Remove trailing slash so it matches exactly
    RedirectUris = { "https://app.example.com/signin-oidc" },

    // Add the required 'openid' scope
    AllowedScopes = { "openid", "profile", "email", "api1" },

    // Enable refresh tokens
    AllowOfflineAccess = true
}
```

## Explanation of each issue

1. **Secret not hashed.** IdentityServer expects client secrets to be stored as a SHA-256 hash by default. `new Secret("super-secret-password")` stores plaintext and won't validate. Use `new Secret("...".Sha256())`.

2. **Trailing slash on redirect URI.** `.../signin-oidc/` won't match the `.../signin-oidc` the client sends. Redirect URIs must match exactly, so the trailing slash causes an invalid redirect URI error. Remove it.

3. **Missing `openid` scope.** Authenticating users is an OpenID Connect operation, which requires the `openid` scope. Without it you won't get an ID token / `sub`. Add `openid`.

4. **`AllowOfflineAccess = false`.** Refresh tokens are only issued when `AllowOfflineAccess = true` (and the client requests `offline_access`). Switch it to `true`.

5. **Hardcoded secret (security).** The secret is committed in source, which is a security risk. Load it from configuration or a secrets manager/vault instead. In production, consider certificate-based (private_key_jwt) authentication to avoid a shared secret entirely.
