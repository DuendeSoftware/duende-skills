# Three Most Important IdentityServer Client Hardening Steps

Based on the identity-security-hardening skill, these are the three most important client hardening controls:

## 1. PKCE Required on All Authorization Code Clients

**`RequirePkce = true`** must be set on every client that uses the authorization code flow — both public and confidential clients. This is the default in Duende IdentityServer and must **never** be set to `false`.

PKCE (Proof Key for Code Exchange, RFC 7636) prevents authorization code interception attacks where a malicious app or network observer steals the authorization code during the redirect. Without PKCE, the code alone is sufficient to obtain tokens.

```csharp
// CORRECT — RequirePkce = true is the default; shown explicitly for clarity
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true, // DO NOT SET TO FALSE IN PRODUCTION
}
```

Setting `RequirePkce = false` is listed as Common Pitfall #1 in the security hardening checklist and makes authorization code interception "trivially exploitable."

## 2. Exact-Match Fully-Qualified Redirect URIs — No Wildcards

Every production redirect URI must be fully qualified and must match exactly. **Wildcards in redirect URIs are a critical attack surface** — they allow an attacker to steer the authorization code to their own controlled endpoint.

```csharp
// CORRECT — fully qualified, exact-match URIs only
RedirectUris = { "https://app.example.com/signin-oidc" }

// WRONG — wildcards allow redirect to attacker-controlled hosts
RedirectUris = { "https://*.example.com/callback" } // Never do this
```

Duende IdentityServer validates redirect URIs by exact string comparison by default. This is the correct behavior and should never be loosened. For legitimate multi-tenant scenarios, implement `IRedirectUriValidator` with explicit allow-listing from a trusted data source — not pattern matching.

## 3. Restrict Grant Types to Only What Each Client Needs (Principle of Least Grant)

Each enabled grant type expands the attack surface. Every client should only allow the grant types it actually uses:

- **Interactive web apps**: `GrantTypes.Code` only (not `CodeAndClientCredentials`)
- **Machine-to-machine services**: `GrantTypes.ClientCredentials` only
- **Public clients (SPAs, native apps)**: `GrantTypes.Code` with PKCE

**Implicit flow (`GrantTypes.Implicit`) must be removed from all clients.** It is deprecated by RFC 9700 because it exposes tokens in URL fragments, browser history, and referrer headers. Authorization code + PKCE replaces implicit flow entirely.

```csharp
// CORRECT — only the grant type this client needs
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code, // Not CodeAndClientCredentials
    RequirePkce = true
}

// WRONG — granting more than needed expands attack surface
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.CodeAndClientCredentials // Never combine user + M2M flows
}
```

These three controls — PKCE enforcement, strict redirect URI matching, and principle of least grant — are the highest-impact, lowest-effort hardening steps per the Production Security Checklist, all marked as "Required."
