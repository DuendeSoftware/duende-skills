# Common JWT Bearer Pitfalls with IdentityServer

## 1. Audience Mismatch

Make sure the `Audience` in your JWT bearer configuration matches what IdentityServer puts in the `aud` claim of the token. If there's a mismatch, the token will be rejected.

```csharp
options.Audience = "api1"; // Must match what the server issues
```

## 2. Middleware Ordering

Ensure `UseAuthentication()` is called before `UseAuthorization()`:

```csharp
app.UseAuthentication();
app.UseAuthorization();
```

If these are reversed, authentication won't run before authorization checks.

## 3. Authority URL Issues

- Make sure the authority URL is reachable from the API
- The API needs to download the discovery document and signing keys at startup
- HTTPS certificate validation may fail in development

## 4. Token Expiration

Check that the token hasn't expired. There's usually a small clock skew tolerance (5 minutes by default), but significant time differences between servers can cause issues.

## 5. Signing Key Changes

If IdentityServer has rotated its signing keys and your API has cached the old JWKS, token validation will fail until the API refreshes its key cache. The default refresh interval is 24 hours.
