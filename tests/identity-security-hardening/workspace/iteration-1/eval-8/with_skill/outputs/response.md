# Three Most Important IdentityServer Client Hardening Steps

## 1. Require PKCE on All Authorization Code Clients

`RequirePkce = true` must be set on every client that uses the authorization code flow. This is the default in Duende IdentityServer — the critical rule is **never set it to `false`**.

PKCE prevents authorization code interception attacks where a malicious app intercepts the authorization code during the redirect. Without PKCE, any application that can observe the redirect URI can exchange the code for tokens.

```csharp
// ✅ Required
new Client
{
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true, // NEVER set to false
}
```

## 2. Exact-Match Fully-Qualified Redirect URIs

Every redirect URI must be fully qualified with scheme, host, and path. No wildcards (`*`), no regex patterns, no path traversal. Wildcard redirect URIs are one of the most critical OAuth attack surfaces — they enable authorization code injection via open redirectors.

```csharp
// ✅ Exact match
RedirectUris = { "https://app.example.com/signin-oidc" }

// ❌ Never wildcards
RedirectUris = { "https://*.example.com/*" }
```

## 3. Restrict Grant Types — Principle of Least Grant

Each client should only have the grant types it actually needs. This means:
- Interactive web apps: `GrantTypes.Code` only (not `CodeAndClientCredentials`)
- Machine-to-machine: `GrantTypes.ClientCredentials` only
- **Never use `GrantTypes.Implicit`** — it is deprecated by RFC 9700

Unused grant types expand the attack surface. A client with `CodeAndClientCredentials` can be exploited for machine-to-machine access even if it was only intended for interactive use.

```csharp
// ✅ Only what's needed
new Client { AllowedGrantTypes = GrantTypes.Code }       // Interactive
new Client { AllowedGrantTypes = GrantTypes.ClientCredentials } // M2M
```

These three controls form the foundation of OAuth 2.0 client security per RFC 9700 (Security BCP). Without them, token theft and replay attacks become trivially exploitable.
