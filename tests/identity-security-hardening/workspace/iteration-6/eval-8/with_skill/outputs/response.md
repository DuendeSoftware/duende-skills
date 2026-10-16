Per the skill's core principles and client checklist, the three highest-impact client hardening steps are:

1. **Require PKCE on every authorization-code client** — `RequirePkce = true` (the default; never set it to `false`), for public *and* confidential clients. It prevents authorization code interception.
2. **Use strict, exact-match redirect URIs** — fully qualified, no wildcards like `https://*.example.com/...`, since wildcards are a critical attack surface (code/token redirection to attacker-controlled hosts).
3. **Restrict grant types per client (least grant)** — disable implicit flow and unused grants; use `GrantTypes.Code` for interactive apps and `ClientCredentials` only for M2M. Never combine user + M2M flows (e.g. `CodeAndClientCredentials`).

Closely related in the same checklist: load secrets from a vault/config (not source), prefer `private_key_jwt`/mTLS for sensitive clients, keep access tokens short (≤ 300 s) and use `OneTimeOnly` refresh tokens.
