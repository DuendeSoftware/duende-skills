# Troubleshooting 401 Unauthorized with JWT Bearer and IdentityServer

Here are the most common pitfalls that cause 401 responses when your JWT looks valid:

## 1. Audience Mismatch

The `Audience` in `JwtBearerOptions` must match the `ApiResource` name in IdentityServer. A mismatch causes 401 responses with no clear error message in the API logs.

```csharp
// IdentityServer: ApiResource name is "api1"
var apiResource = new ApiResource("api1") { Scopes = { "api1.read" } };

// API: Audience must match exactly
options.Audience = "api1"; // Must match ApiResource name
```

If you set `options.Audience = "myapi"` but the ApiResource is named `"api1"`, all tokens will be rejected.

## 2. Missing ValidTypes for at+jwt

Without setting `ValidTypes = ["at+jwt"]`, you're not only vulnerable to JWT confusion attacks, but misconfigurations can cause identity tokens to be accidentally accepted. More importantly, if you DO set this but IdentityServer isn't setting the `typ` header correctly, tokens will be rejected.

```csharp
options.TokenValidationParameters.ValidTypes = ["at+jwt"];
```

This validates that the token's `typ` header is `at+jwt` (per RFC 9068). Without it, an attacker could present an identity token as an access token.

## 3. Scope Claim Format Inconsistency

If IdentityServer emits scopes as a space-delimited string (`"scope": "api1.read api1.write"`) but your authorization policies expect individual claims, authorization will fail **silently** — the user gets a 403 Forbidden after authentication succeeds.

Implement an `IClaimsTransformation` to normalize space-delimited scopes into individual claims.

## 4. Middleware Pipeline Ordering

`UseAuthentication()` must come before `UseAuthorization()`. If reversed, authorization runs before authentication and all requests are unauthorized.

```csharp
// ✅ Correct order
app.UseAuthentication();
app.UseAuthorization();

// ❌ Wrong order — causes 401 for all requests
app.UseAuthorization();
app.UseAuthentication();
```

## 5. Additional Checks

- Verify the IdentityServer authority URL is reachable from the API
- Check the token hasn't expired
- Ensure the signing key rotation hasn't invalidated cached JWKS
- Check for clock skew between servers
