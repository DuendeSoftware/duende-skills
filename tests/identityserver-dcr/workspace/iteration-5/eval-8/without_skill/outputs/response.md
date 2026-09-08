# Hardening Dynamic Client Registration: common mistakes to avoid

DCR (RFC 7591) is convenient but expands your attack surface — you're letting external parties create OAuth/OIDC clients. Here are the mistakes teams most often make, and how to avoid them.

## 1. Leaving the registration endpoint open

By far the most common and most severe mistake: exposing the registration endpoint (e.g. `/connect/dcr`) with no authentication or authorization. An open endpoint lets anyone create clients — potentially with attacker-controlled redirect URIs used to steal authorization codes and tokens.

**Fix:** Require authentication and authorization. Protect the endpoint with a bearer token and a dedicated scope/policy, e.g. `RequireAuthorization("dcr")` on the mapped endpoint. Only trusted, authorized callers should register clients.

## 2. Allowing any grant type / not enforcing PKCE

If registrants can request arbitrary grant types, they may enable insecure flows such as the implicit flow or resource-owner password. Public clients without PKCE are vulnerable to authorization code interception.

**Fix:** Restrict the allowed grant types (prefer `authorization_code` only) and **require PKCE** for all registered clients. Validate and constrain this server-side during registration rather than trusting the request.

## 3. Not restricting/validating redirect URIs

Accepting arbitrary redirect URIs — especially non-HTTPS or wildcard URIs — enables open-redirect and token-theft attacks.

**Fix:** Enforce HTTPS on all redirect URIs, reject loopback/`http://` in production, and validate them against your policy (exact match, allow-lists where feasible).

## 4. Using in-memory stores in production

In-memory client stores lose all dynamically registered clients on restart and don't work across multiple/load-balanced instances, so registrations silently disappear or become inconsistent.

**Fix:** Persist dynamically registered clients in a durable, shared database-backed store in production. Never rely on in-memory storage for DCR clients.

## 5. Storing client secrets in plaintext

Registration issues secrets to confidential clients. Storing those secrets in plaintext means a database breach hands attackers working credentials.

**Fix:** Store secrets **hashed** (e.g. SHA-256), never in plaintext. Treat them like passwords.

## 6. Blindly trusting software statements

Software statements are signed JWTs asserting pre-approved client metadata. Accepting them without verifying the signature, or trusting unknown issuers, lets attackers forge "approved" clients.

**Fix:** Validate the software statement's signature against **trusted signing keys** and verify the issuer is one you trust. Reject statements with invalid signatures or from unknown issuers; fetch keys from the trusted issuer's published JWKS, not from the token.

## Additional good practices

- **Least privilege on scopes** — don't let registrants request high-privilege scopes; constrain what a registered client can ask for.
- **Rate limiting & monitoring** — throttle and audit-log registrations to detect abuse.
- **Short-lived, tightly-scoped registration tokens** — the token used to call the endpoint should be narrow and expire quickly.
- **TLS everywhere** — the registration endpoint and all client endpoints must be HTTPS.

## Quick checklist

- [ ] Registration endpoint requires auth + scope
- [ ] Grant types restricted; PKCE enforced
- [ ] Redirect URIs validated (HTTPS, allow-list)
- [ ] Clients persisted in a durable store (not in-memory)
- [ ] Secrets stored hashed
- [ ] Software statements validated against trusted keys/issuers
- [ ] Scopes constrained, endpoint rate-limited and monitored
