Let me review the client configuration and identify the issues:

### Issue 1: Missing `.Sha256()` on the Secret

```csharp
// ❌ Original
ClientSecrets = { new Secret("super-secret-password") }

// ✅ Fixed
ClientSecrets = { new Secret("super-secret-password".Sha256()) }
```

The secret needs to be hashed before storing. Without `.Sha256()`, the raw string is stored and authentication will fail because IdentityServer hashes the incoming secret for comparison.

### Issue 2: Trailing Slash on Redirect URI

```csharp
// ❌ Original
RedirectUris = { "https://app.example.com/signin-oidc/" }

// ✅ Fixed
RedirectUris = { "https://app.example.com/signin-oidc" }
```

Redirect URIs must match exactly. The OIDC middleware typically sends the redirect without a trailing slash, so the trailing slash causes a mismatch.

### Issue 3: Missing `openid` Scope

```csharp
// ❌ Original
AllowedScopes = { "profile", "email", "api1" }

// ✅ Fixed
AllowedScopes = { "openid", "profile", "email", "api1" }
```

The `openid` scope is required for OpenID Connect. Without it, IdentityServer won't issue an identity token and user authentication will fail.

### Issue 4: AllowOfflineAccess Should Be True

```csharp
// ❌ Original
AllowOfflineAccess = false

// ✅ Fixed
AllowOfflineAccess = true
```

To receive refresh tokens, `AllowOfflineAccess` must be set to `true`.

### Fixed Configuration

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("super-secret-password".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    AllowedScopes = { "openid", "profile", "email", "api1" },
    AllowOfflineAccess = true
}
```
