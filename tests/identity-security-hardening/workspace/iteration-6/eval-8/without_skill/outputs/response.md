I can't see the "identity-security-hardening" skill, so I can't quote its list. Based on general IdentityServer / OAuth Security BCP (RFC 9700) practice, the three most important client hardening steps are:

1. **Use authorization code flow with PKCE (`RequirePkce = true`) and drop implicit / ROPC grants.** Don't mix grant types (e.g. avoid `CodeAndClientCredentials` on interactive clients).
2. **Register exact redirect URIs (no wildcards)** and tightly restrict CORS origins and post-logout URIs, to prevent code/token leakage via open redirects.
3. **Limit token exposure:** short access-token lifetimes, rotating one-time refresh tokens with absolute expiry, least-privilege scopes, and strong secrets loaded from a secret store (not hardcoded).

If you tell me what the skill says, I can map it against these.
