# Security Audit

## Issues Found

### 1. Developer Signing Credential
Using `AddDeveloperSigningCredential()` in production is not recommended. Replace with a proper signing key.

### 2. Implicit Flow
The `spa.legacy` client uses implicit flow which is deprecated. Switch to authorization code with PKCE:

```csharp
AllowedGrantTypes = GrantTypes.Code,
RequirePkce = true,
RequireClientSecret = false
```

### 3. PKCE Disabled
The `web.app` client has `RequirePkce = false`. This should be `true`.

### 4. Wildcard Redirect URIs
`https://*.example.com/signin-oidc` should be replaced with specific URIs.

### 5. Long Access Token Lifetime
8-hour access tokens are too long. Reduce to 15 minutes or less:

```csharp
AccessTokenLifetime = 900
```

### 6. Hardcoded Secrets
Secrets should be loaded from configuration instead of hardcoded.

### 7. No HTTPS Configuration
Add HSTS and HTTPS redirection.

## Summary

The main issues are the developer signing credential, implicit flow usage, disabled PKCE, wildcard redirect URIs, long token lifetimes, and hardcoded secrets. These should all be remediated before going to production.
