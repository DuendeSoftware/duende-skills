# Common DCR security mistakes

1. **Unauthenticated /connect/dcr.** Anyone could create clients. Require a bearer token with a dedicated scope.
2. **Overly broad scope/credentials.** Don't reuse a general scope or let normal clients get the configuration scope. Rotate secrets; prefer private_key_jwt.
3. **Not validating grant types.** Allowing client_credentials, implicit or password lets registrants mint tokens or weaken flows. Allow-list them.
4. **Weak redirect URI validation.** http, wildcards, or unreviewed custom schemes enable code theft. Require HTTPS and exact matches.
5. **Not forcing PKCE.**
6. **Unrestricted scopes.** Registrants requesting `api1`, `offline_access` or admin scopes. Constrain what dynamic clients may get.
7. **Trusting client metadata** (logo_uri, client_uri, jwks_uri, policy_uri): SSRF and phishing risks; validate and cap lengths.
8. **No software statement verification** when relied upon; accept only signed statements from trusted issuers with pinned algorithms.
9. **In-memory store in production**: lost clients, inconsistency across nodes. Use EF.
10. **No rate limiting, quotas or auditing**: attackers can fill your DB. Log every registration.
11. **Exposing DCR publicly** when only internal tooling needs it. Restrict network access or host separately.
12. **Sloppy token validation**: audience, `at+jwt` type, issuer.
13. **No cleanup** of stale registrations.

Hardening checklist: authN + scope policy, custom validator (grant types, HTTPS URIs, PKCE, scope allow-list), EF store, rate limits, logging/alerts, secrets in a vault.
