# Debugging 401s with JWT bearer + IdentityServer

A syntactically valid JWT that still returns `401` almost always means the API rejected it during validation or the principal wasn't established. Here are the common culprits, in the order I'd check them.

## 1. Audience mismatch (the most common cause)

`JwtBearerOptions.Audience` must **exactly match the `ApiResource` name** in IdentityServer, which is what ends up in the token's `aud` claim. If they differ, validation fails and you get a `401` with no useful message in the API logs.

```csharp
options.Audience = "api1"; // must equal the ApiResource name in IdentityServer
```

Decode the token (e.g. jwt.ms) and confirm `aud` contains exactly what you set in `Audience`. If your token has multiple audiences, use `ValidAudiences`.

## 2. Missing `ValidTypes = ["at+jwt"]`

IdentityServer stamps access tokens with the `typ` header `at+jwt` (RFC 9068). You should enforce it:

```csharp
options.TokenValidationParameters.ValidTypes = ["at+jwt"];
```

Two failure modes here:
- If you set `ValidTypes` to something that doesn't match the token's `typ`, valid access tokens are rejected → `401`.
- If you **omit** it entirely, you lose protection against **JWT confusion attacks** — an identity token (also a JWT signed by the same issuer) could be replayed as an access token. Always validate `at+jwt`, but make sure the value matches what IdentityServer actually emits.

## 3. Scope claim format inconsistency

IdentityServer can emit `scope` as a JSON array (default) **or** as a single space-delimited string (`EmitScopesAsSpaceDelimitedStringInJwt = true`). If your policies do `RequireClaim("scope", "api1.read")` but the token carries `"scope": "api1.read api1.write"` as one value, the claim check fails **silently** — authentication succeeds but authorization returns `403`/`401`. Normalize with a custom `IClaimsTransformation` that splits the space-delimited scope into individual claims.

## 4. Middleware ordering

`UseAuthentication()` must come **before** `UseAuthorization()`. If reversed (or if `UseAuthentication` is missing), the request principal isn't populated when authorization runs, so every protected endpoint returns `401`.

```csharp
app.UseAuthentication();
app.UseAuthorization();
```

Also ensure both sit after `UseRouting()` and before your endpoint mappings.

## Quick checklist

| Symptom | Likely cause |
| --- | --- |
| `401`, token decodes fine | `aud` ≠ `Audience`, or `typ` ≠ `ValidTypes` |
| Authenticated but forbidden | scope claim is space-delimited, not split |
| Every protected route `401` | `UseAuthentication` missing or after `UseAuthorization` |
| Signature/issuer errors | `Authority` wrong, or metadata unreachable over HTTPS |

Turn on `Microsoft.AspNetCore.Authentication` debug logging to see the exact validation failure — it usually names the failing check (audience, lifetime, signature, or type).
