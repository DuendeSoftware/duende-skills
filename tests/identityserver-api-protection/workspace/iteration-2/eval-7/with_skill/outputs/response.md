# Troubleshooting 401 Unauthorized with JWT Bearer Authentication

Here are the most common pitfalls when protecting APIs with IdentityServer:

## 1. Audience Mismatch

The `Audience` in `JwtBearerOptions` must match the `ApiResource` name configured in IdentityServer. A mismatch causes 401 responses with no clear error message in the API logs.

```csharp
// ❌ If IdentityServer has ApiResource("api1"), this will fail:
options.Audience = "my-api"; // Does not match!

// ✅ Must match exactly:
options.Audience = "api1";
```

If `Audience` is not set at all, audience validation is skipped — which may mask this issue in development but creates a security hole.

## 2. Missing ValidTypes for `at+jwt`

Without `ValidTypes = ["at+jwt"]`, the API is vulnerable to JWT confusion attacks. But more subtly, some configurations may cause legitimate access tokens to be rejected if the type validation doesn't match:

```csharp
// ✅ Always set ValidTypes
options.TokenValidationParameters.ValidTypes = ["at+jwt"];
```

IdentityServer sets the `typ` header to `at+jwt` on all access token JWTs per RFC 9068. Without this validation, an identity token (which is also a JWT signed by the same issuer) could be presented to the API.

## 3. Scope Claim Format Inconsistency

IdentityServer can emit scopes either as a JSON array or as a space-delimited string (controlled by `EmitScopesAsSpaceDelimitedStringInJwt`). If your authorization policies use `RequireClaim("scope", "api1.read")` but the scope claim is `"api1.read api1.write"` (a single space-delimited string), the policy check will fail silently.

**Solution**: Implement a custom `IClaimsTransformation` that splits space-delimited scope claims into individual claims.

## 4. Middleware Pipeline Ordering

`UseAuthentication()` must be called before `UseAuthorization()`:

```csharp
// ❌ Wrong order — auth middleware runs after authorization
app.UseAuthorization();
app.UseAuthentication(); // Too late!

// ✅ Correct order
app.UseAuthentication();
app.UseAuthorization();
```

If `UseAuthentication()` comes after `UseAuthorization()`, the authorization middleware won't have access to the authenticated user, and every request will appear unauthenticated.

## 5. Additional Checks

- **Clock skew**: The default clock skew for JWT validation is 5 minutes. If your server clock is significantly off, tokens may be rejected as expired.
- **HTTPS requirements**: In production, ensure Authority uses HTTPS. Development may use `options.RequireHttpsMetadata = false` but this should never be in production.
- **Discovery document**: The JWT bearer handler fetches the discovery document from `{Authority}/.well-known/openid-configuration`. If the Authority URL is wrong or unreachable, authentication will fail at startup.
