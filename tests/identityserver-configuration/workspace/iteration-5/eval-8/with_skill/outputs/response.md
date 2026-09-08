# Fixing the Client Configuration

There are four functional bugs plus one security concern. Here's the corrected client, followed by an explanation of each issue.

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,

    // (1) Secret must be stored as a SHA-256 hash — and (5) not hardcoded
    ClientSecrets = { new Secret(configuration["Clients:MyWebApp:Secret"].Sha256()) },

    // (2) No trailing slash — must match exactly what the client sends
    RedirectUris = { "https://app.example.com/signin-oidc" },

    // (3) 'openid' is required for OpenID Connect authentication
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.Email,
        "api1"
    },

    // (4) Enable refresh tokens
    AllowOfflineAccess = true
}
```

## Issues Explained

1. **Missing `.Sha256()` on the secret.** `new Secret("super-secret-password")` stores the raw string as the stored secret value. IdentityServer's default secret validator compares the *SHA-256 hash* of the presented secret against the stored value, so a plaintext-stored secret won't validate. Fix: `new Secret("...".Sha256())`.

2. **Trailing slash on the redirect URI.** `"https://app.example.com/signin-oidc/"` will not match the `https://app.example.com/signin-oidc` (no slash) that the OIDC client actually sends, producing an `invalid_redirect_uri` error. Redirect URIs are matched by exact string comparison — remove the trailing slash.

3. **Missing `openid` scope.** The app "needs to authenticate users," which is an OpenID Connect flow — and OIDC *requires* the `openid` scope (it's what returns the `sub` claim and an identity token). The original only had `profile`, `email`, `api1`. Add `IdentityServerConstants.StandardScopes.OpenId`.

4. **`AllowOfflineAccess = false` blocks refresh tokens.** To use refresh tokens the client must have `AllowOfflineAccess = true` (and request the `offline_access` scope). With it `false`, no refresh token is ever issued. Change it to `true`.

5. **Security: hardcoded secret in source.** `"super-secret-password"` is committed to source control — a real risk. Load the secret from configuration, environment, or a secret vault instead of embedding it. Even better for production, use asymmetric client authentication (`private_key_jwt` or mTLS) so no shared secret is transmitted at all.
