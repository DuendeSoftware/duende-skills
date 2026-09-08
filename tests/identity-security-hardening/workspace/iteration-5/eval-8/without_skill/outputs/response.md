# Top Client Hardening Steps for IdentityServer

I don't have that specific skill document in front of me, but based on OAuth 2.0 security best practices (RFC 9700) and standard IdentityServer hardening guidance, the three most important client hardening steps are:

## 1. Require PKCE for all authorization code clients

Set `RequirePkce = true` on every client using the authorization code flow, including confidential ones. PKCE protects the authorization code from being intercepted and exchanged by an attacker. It's the default in Duende IdentityServer and should never be disabled.

## 2. Use exact, fully-qualified redirect URIs — no wildcards

Redirect URIs should be exact-match HTTPS URLs with no wildcards. Wildcard patterns like `https://*.example.com/callback` create an open-redirect risk where an attacker could receive the authorization code at a host they control.

## 3. Limit each client to the minimum grant types it needs, and drop implicit flow

Only enable the grant types a client actually uses (principle of least privilege). Remove the legacy implicit flow entirely — it's deprecated because it exposes tokens in the browser — and replace it with authorization code + PKCE. Avoid mixing user and machine flows on the same client.

These three address the most common OAuth attack surface for clients: code interception, open redirects, and unnecessary/insecure grant types.
