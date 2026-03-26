# Client Configuration Review and Fixes

Here are all the issues in the original configuration, with explanations and fixes:

## Issue 1: Missing .Sha256() on Client Secret

```csharp
// WRONG
ClientSecrets = { new Secret("super-secret-password") }

// FIXED
ClientSecrets = { new Secret("super-secret-password".Sha256()) }
```

**Problem:** The `Secret` constructor expects a hashed value. Without `.Sha256()`, the raw string is stored as the secret value, and client authentication will fail because IdentityServer compares the hash of the incoming secret against the stored value.

## Issue 2: Trailing Slash on Redirect URI

```csharp
// WRONG - trailing slash
RedirectUris = { "https://app.example.com/signin-oidc/" }

// FIXED - exact match required
RedirectUris = { "https://app.example.com/signin-oidc" }
```

**Problem:** Redirect URI matching is exact. The ASP.NET Core OIDC middleware sends `https://app.example.com/signin-oidc` (no trailing slash). The trailing slash causes an `invalid_redirect_uri` error during the authorization flow.

## Issue 3: Missing 'openid' Scope

```csharp
// WRONG - missing openid scope
AllowedScopes = { "profile", "email", "api1" }

// FIXED - openid is required for OIDC
AllowedScopes =
{
    IdentityServerConstants.StandardScopes.OpenId,
    IdentityServerConstants.StandardScopes.Profile,
    IdentityServerConstants.StandardScopes.Email,
    "api1"
}
```

**Problem:** The `openid` scope is mandatory for any OpenID Connect authentication request. Without it, the client can't authenticate users - it's required by the OIDC specification. The `profile` and `email` scopes depend on `openid` being present.

## Issue 4: AllowOfflineAccess Should Be True

```csharp
// WRONG - can't get refresh tokens
AllowOfflineAccess = false

// FIXED - enables refresh token issuance
AllowOfflineAccess = true
```

**Problem:** The app needs refresh tokens for long-lived API access. `AllowOfflineAccess = false` means the client won't receive a refresh token even if it requests the `offline_access` scope.

## Issue 5: Hardcoded Secret (Security Concern)

```csharp
// WRONG - secret in source code
ClientSecrets = { new Secret("super-secret-password".Sha256()) }

// BETTER - load from configuration or vault
ClientSecrets = { new Secret(configuration["Clients:WebApp:Secret"].Sha256()) }
```

**Problem:** Hardcoding secrets in source code is a security risk. Secrets should be loaded from configuration, environment variables, or a secret vault (like Azure Key Vault or HashiCorp Vault). Source code is often committed to version control, making secrets visible to anyone with repo access.

## Complete Fixed Client

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret(configuration["Clients:WebApp:Secret"].Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowOfflineAccess = true,
    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.Email,
        "api1"
    }
}
```
