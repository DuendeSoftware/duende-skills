# The Three Most Important Client Hardening Steps

According to the identity-security-hardening skill, the three highest-impact client hardening controls are:

## 1. Require PKCE on every authorization code client

`RequirePkce = true` on every client that uses the authorization code flow — public *and* confidential. PKCE prevents authorization code interception attacks. It is the default in Duende IdentityServer and **must never be set to `false`** in production.

```csharp
new Client
{
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true   // never set to false
}
```

## 2. Use exact-match, fully-qualified redirect URIs (no wildcards)

Every redirect URI must be a fully-qualified, exact-match HTTPS URI. Wildcards are a critical attack surface — an open redirector lets an attacker steer the authorization code to a host they control.

```csharp
// ✅ exact match
RedirectUris = { "https://app.example.com/signin-oidc" }
// ❌ never
RedirectUris = { "https://*.example.com/callback" }
```

## 3. Restrict grant types to only what the client needs (principle of least grant), and remove implicit flow

Each enabled grant type expands the attack surface. Allow only the grant types a client actually uses, never combine interactive + M2M flows (e.g. `CodeAndClientCredentials`), and eliminate the deprecated implicit flow entirely — replace it with authorization code + PKCE.

```csharp
// ✅ interactive app: code only
AllowedGrantTypes = GrantTypes.Code
// ❌ implicit flow — deprecated by RFC 9700
AllowedGrantTypes = GrantTypes.Implicit
```

These three are called out because they are the highest-impact, lowest-effort steps: disabling implicit flow and unused grants, enforcing PKCE, and locking down redirect URIs close off the most common OAuth attack vectors.
