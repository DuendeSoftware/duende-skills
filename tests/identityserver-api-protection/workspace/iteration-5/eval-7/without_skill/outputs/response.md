# Common causes of unexpected 401s with JWT bearer authentication

If the token looks valid but the API still returns `401`, the problem is usually in how the API validates it or how the pipeline is wired. Work through these:

## 1. Audience mismatch

`JwtBearerOptions.Audience` (or `ValidAudience`) must match the `aud` claim in the token, which corresponds to the API/resource name registered in your identity provider. If they differ, the token is rejected. Decode the JWT and compare `aud` to your configured `Audience`.

```csharp
options.Audience = "api1"; // must equal the resource/audience the token was issued for
```

## 2. Authority / issuer problems

- `Authority` must point at the correct identity provider and be reachable so the middleware can load the discovery document and signing keys (JWKS).
- The token's `iss` must match the issuer the metadata advertises. A trailing-slash or http-vs-https difference will break issuer validation.
- In production keep `RequireHttpsMetadata = true`; if metadata can't be fetched, all validation fails.

## 3. Signing key / expiration issues

- If the signing keys rotated and the API cached stale JWKS, signature validation fails. Restarting or letting the key cache refresh helps.
- Check `exp`/`nbf` — a valid-looking token may simply be expired, or clock skew between servers may reject a fresh one. You can tune `TokenValidationParameters.ClockSkew`.

## 4. Middleware ordering

`UseAuthentication()` must be called **before** `UseAuthorization()`, and both after `UseRouting()`. If authentication runs after authorization (or is missing), the user is never set and protected endpoints return `401`.

```csharp
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
```

## 5. Scheme mismatch

If `[Authorize]` or a policy specifies a scheme that doesn't match the one you registered in `AddJwtBearer("...")`, the request won't authenticate. Make sure the default scheme and any explicitly named schemes line up.

## How to diagnose

Enable authentication debug logging:

```json
"Logging": { "LogLevel": { "Microsoft.AspNetCore.Authentication": "Debug" } }
```

The logs will tell you exactly which validation step failed — audience, issuer, signature, or lifetime — which usually points straight at the misconfiguration.
