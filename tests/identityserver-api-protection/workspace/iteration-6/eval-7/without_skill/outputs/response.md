# Common causes of 401 with a "valid-looking" JWT

1. **Audience mismatch** – the `aud` claim must equal `Audience`. IdentityServer only emits `aud` if the ApiResource is requested/defined; with ApiScopes only, `aud` may be absent (set `ValidateAudience = false` deliberately or define ApiResources).
2. **Issuer mismatch** – `iss` must exactly equal the authority's issuer (trailing slash, http vs https, behind proxies/containers different host names).
3. **Authority unreachable / untrusted cert** – API can't download discovery or JWKS (DNS, Docker networking, dev certs). Check logs for `IDX20803`.
4. **Missing `UseAuthentication()`** or wrong order (before `UseAuthorization`, after `UseRouting`).
5. **Token type** – `typ` header is `at+jwt`; if you set `ValidTypes` incorrectly (e.g. only `JWT`) it fails. Conversely ID tokens shouldn't be accepted.
6. **Clock skew / expiry** – `exp`/`nbf` off due to server clock drift.
7. **Signing key rotation / cached keys** – the API cached old JWKS; refresh or restart.
8. **Wrong scheme** – `[Authorize]` uses a different default scheme than the one configured; specify `AuthenticationSchemes`.
9. **Claim mapping** – `MapInboundClaims` renames claims (`sub`, `scope`, `role`), making policies fail (this usually gives 403, not 401).
10. **Header format** – needs `Authorization: Bearer <token>`; DPoP tokens need `DPoP` scheme and a proof.
11. **Reference token sent to JWT handler** – opaque tokens need introspection.
12. **HTTPS metadata** – `RequireHttpsMetadata` with an http authority.

Debugging: set `Microsoft.AspNetCore.Authentication` logging to Debug/Trace, look at `WWW-Authenticate` header (`error="invalid_token"`, `error_description`), and use `JwtBearerEvents.OnAuthenticationFailed` temporarily. Decode the token on jwt.io to compare `iss`, `aud`, `exp`, `typ`.
