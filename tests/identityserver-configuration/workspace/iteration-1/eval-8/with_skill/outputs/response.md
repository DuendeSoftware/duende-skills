Here's a review of each issue in the client configuration, along with the fixes:

### Issue 1: Missing `.Sha256()` on the Client Secret

```csharp
// ❌ Original — plaintext secret stored directly
ClientSecrets = { new Secret("super-secret-password") }

// ✅ Fixed — secret must be hashed with Sha256
ClientSecrets = { new Secret("super-secret-password".Sha256()) }
```

**Why:** Duende IdentityServer stores secrets as SHA-256 hashes. The `new Secret(value)` constructor expects a pre-hashed value. Without `.Sha256()`, the raw string is stored as-is, and when a client authenticates, IdentityServer hashes the incoming secret and compares it — the comparison will always fail because the stored value was never hashed.

### Issue 2: Trailing Slash on Redirect URI

```csharp
// ❌ Original — trailing slash
RedirectUris = { "https://app.example.com/signin-oidc/" }

// ✅ Fixed — exact match required, no trailing slash
RedirectUris = { "https://app.example.com/signin-oidc" }
```

**Why:** Redirect URI validation is an exact string match (per the OAuth 2.0 spec). The ASP.NET Core OIDC middleware sends `https://app.example.com/signin-oidc` (no trailing slash) as the `redirect_uri` parameter. If the registered URI has a trailing slash, IdentityServer returns an `invalid_redirect_uri` error and the login flow fails.

### Issue 3: Missing `openid` Scope

```csharp
// ❌ Original — no openid scope
AllowedScopes = { "profile", "email", "api1" }

// ✅ Fixed — openid is mandatory for OIDC
AllowedScopes =
{
    IdentityServerConstants.StandardScopes.OpenId,  // Required
    IdentityServerConstants.StandardScopes.Profile,
    IdentityServerConstants.StandardScopes.Email,
    "api1"
}
```

**Why:** The `openid` scope is mandatory for any OpenID Connect authentication request. It tells IdentityServer to issue an identity token containing the `sub` (subject ID) claim. Without it, the request is treated as a plain OAuth 2.0 request — no identity token is issued, and user authentication fails.

### Issue 4: `AllowOfflineAccess` Should Be `true`

```csharp
// ❌ Original — refresh tokens disabled
AllowOfflineAccess = false

// ✅ Fixed — enable refresh tokens
AllowOfflineAccess = true
```

**Why:** `AllowOfflineAccess` controls whether the `offline_access` scope is permitted and whether refresh tokens are issued. Setting it to `false` (the default) means the client will never receive a refresh token, even if it requests the `offline_access` scope. Since the requirement states the app needs refresh tokens, this must be `true`.

### Issue 5: Hardcoded Secret in Source Code

```csharp
// ⚠️ Security concern — secret is hardcoded in source code
ClientSecrets = { new Secret("super-secret-password".Sha256()) }

// ✅ Better — load from configuration or a secrets vault
ClientSecrets = { new Secret(configuration["Clients:MyWebApp:Secret"].Sha256()) }
```

**Why:** Hardcoding secrets in source code means they end up in version control, build artifacts, and logs. In production, secrets should be loaded from configuration (environment variables, Azure Key Vault, AWS Secrets Manager, etc.) or replaced entirely with asymmetric credentials (e.g., private_key_jwt client authentication).

### Complete Fixed Configuration

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret(configuration["Clients:MyWebApp:Secret"].Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.Email,
        "api1"
    },
    AllowOfflineAccess = true
}
```
