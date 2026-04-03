# Three Most Important IdentityServer Client Hardening Steps

## 1. Enable PKCE (Proof Key for Code Exchange)

All clients using the authorization code flow should have PKCE enabled. PKCE protects against authorization code interception attacks by binding the code to the original authorization request.

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true  // Always enable for code flow clients
}
```

Setting `RequirePkce = false` removes this protection and should not be done in production.

## 2. Use Exact Redirect URIs

Redirect URIs should be exact-match, fully-qualified HTTPS URIs. Wildcards in redirect URIs can be exploited to redirect authorization codes to attacker-controlled endpoints.

```csharp
// Good: specific, fully-qualified URI
RedirectUris = { "https://app.example.com/signin-oidc" }

// Bad: wildcard allows redirects to any subdomain
RedirectUris = { "https://*.example.com/callback" }
```

## 3. Use the Minimum Required Grant Types

Each client should only have the grant types it actually needs. Don't combine grant types unnecessarily:

- Web apps: Use `GrantTypes.Code`
- APIs/services: Use `GrantTypes.ClientCredentials`  
- SPAs: Use `GrantTypes.Code` (not `Implicit`)

The implicit flow should be avoided entirely in favor of authorization code flow with PKCE, as it exposes tokens in the URL fragment.
