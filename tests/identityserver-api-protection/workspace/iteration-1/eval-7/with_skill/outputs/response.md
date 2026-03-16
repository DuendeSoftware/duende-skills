# Troubleshooting 401 Unauthorized with JWT Bearer and IdentityServer

Here are the most common causes of 401 Unauthorized responses when validating JWTs from IdentityServer, and how to fix each one.

## 1. Audience Mismatch

**The most common cause.** The `Audience` in your `JwtBearerOptions` must exactly match the `ApiResource` name configured in IdentityServer.

```csharp
// IdentityServer configuration
var apiResource = new ApiResource("api1") // ← This is the audience value
{
    Scopes = { "api1.read", "api1.write" }
};

// API configuration — Audience must match the ApiResource name
options.Audience = "api1"; // ✅ Matches
options.Audience = "Api1"; // ❌ Case-sensitive mismatch
options.Audience = "my-api"; // ❌ Wrong name
```

The `aud` claim in the JWT must contain the value set in `Audience`. If there's a mismatch, the JWT bearer handler rejects the token silently — you'll see a 401 with no clear error in the API logs. Check the token's `aud` claim (decode it at jwt.io) and compare it to your `JwtBearerOptions.Audience`.

## 2. Missing ValidTypes for at+jwt

**JWT confusion attack vector.** Without `ValidTypes`, the API will accept any JWT signed by the issuer — including identity tokens that aren't meant for API access.

```csharp
// ❌ Vulnerable: No type validation
options.TokenValidationParameters = new TokenValidationParameters
{
    ValidateAudience = true
};

// ✅ Secure: Validate the at+jwt type header
options.TokenValidationParameters.ValidTypes = ["at+jwt"];
```

IdentityServer sets the `typ` header to `at+jwt` on access tokens (per RFC 9068). If you're receiving identity tokens or tokens from another source that don't have this type, they'll be rejected — which is the correct behavior. But if your legitimate access tokens are being rejected, verify that IdentityServer is setting the `typ` header correctly (check `IdentityServerOptions.AccessTokenJwtType`).

## 3. Scope Claim Format Inconsistency

**Silent authorization failures.** IdentityServer can emit scopes in two formats:

- **Array (default):** `"scope": ["api1.read", "api1.write"]` — each scope is a separate claim
- **Space-delimited:** `"scope": "api1.read api1.write"` — single claim with spaces

If your authorization policies use `RequireClaim("scope", "api1.read")` but scopes are emitted as a space-delimited string, the policy check compares against the full string `"api1.read api1.write"` and fails silently.

**Fix:** Implement a custom `IClaimsTransformation` to split space-delimited scope claims:

```csharp
builder.Services.AddTransient<IClaimsTransformation, ScopeClaimsTransformation>();
```

This is controlled by IdentityServer's `EmitScopesAsSpaceDelimitedStringInJwt` setting. The format can change between environments, so always normalize.

## 4. Middleware Pipeline Ordering

**Authentication must come before authorization.** If `UseAuthorization()` runs before `UseAuthentication()`, the identity is never established and all requests are treated as anonymous.

```csharp
// ❌ WRONG: Authorization before authentication
app.UseAuthorization();
app.UseAuthentication(); // Too late — authorization already ran

// ✅ CORRECT: Authentication first
app.UseAuthentication();
app.UseAuthorization();
```

## Additional Debugging Tips

- **Enable detailed logging:** Set `Microsoft.AspNetCore.Authentication` to `Debug` level in your logging configuration to see exactly why tokens are being rejected.
- **Decode the token:** Use jwt.io or `jq` to inspect the token's claims — check `aud`, `iss`, `scope`, `typ`, and `exp`.
- **Check the discovery document:** Verify your API can reach `{authority}/.well-known/openid-configuration` and download the signing keys.
- **Check token expiration:** Expired tokens return 401. Check the `exp` claim.
