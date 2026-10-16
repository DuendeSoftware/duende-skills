# Common JWT bearer pitfalls with IdentityServer (401s)

1. **Audience mismatch** – `JwtBearerOptions.Audience` must equal the `ApiResource` name in IdentityServer. Mismatches produce a 401 with little explanation in API logs. Compare the token's `aud` claim to your config. If the token has no `aud`, make sure the client requested a scope belonging to an `ApiResource`.
2. **`ValidTypes` misconfigured** – IdentityServer issues `typ: at+jwt` (`AccessTokenJwtType`). Set `options.TokenValidationParameters.ValidTypes = ["at+jwt"]`; omitting it opens JWT confusion attacks, while setting a different value rejects legit tokens. Also don't replace `TokenValidationParameters` wholesale, losing defaults.
3. **Reference token sent to a JWT handler** – opaque tokens can't be validated as JWTs. Use `AddOAuth2Introspection` or support both via `ForwardReferenceToken("introspection")` (scheme names must match exactly).
4. **Introspection 401 / `active: false`** – the `ApiResource` needs `ApiSecrets` and matching `ClientId`/`ClientSecret`; scopes must belong to that resource.
5. **DPoP-bound tokens** – with `cnf.jkt` tokens, the API must have `ConfigureDPoPTokensForScheme` (on `IServiceCollection`, not in the `AddJwtBearer` lambda) and the client must send `Authorization: DPoP` + proof. Missing keyed `HybridCache` for replay detection throws `InvalidOperationException`; stale nonces return `use_dpop_nonce`.
6. **mTLS-bound tokens** – the `cnf` `x5t#S256` must match the client certificate on the connection.
7. **Scope claim format** – with `EmitScopesAsSpaceDelimitedStringInJwt`, a single space-delimited claim breaks `RequireClaim("scope", ...)` (that yields 403 rather than 401); normalize via `IClaimsTransformation`.
8. **Local API in a separate host** – `AddLocalApiAuthentication` only works co-hosted with IdentityServer; clients need the `IdentityServerApi` scope.
9. **Basic setup issues** – missing `UseAuthentication()` before `UseAuthorization()`, wrong scheme referenced by `[Authorize]`, wrong `Authority` (issuer/trailing slash/proxy host), API unable to reach discovery/JWKS, clock skew/expired token.

## Debugging
Set `Microsoft.AspNetCore.Authentication` logging to Debug, inspect the `WWW-Authenticate` header (`error_description`), and compare `iss`, `aud`, `typ`, `exp` and `scope` in the decoded token with your configuration.
