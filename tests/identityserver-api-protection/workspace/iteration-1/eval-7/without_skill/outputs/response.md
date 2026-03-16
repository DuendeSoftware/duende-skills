# Troubleshooting 401 Unauthorized with JWT Bearer Authentication

Getting a 401 when your JWT looks valid can be frustrating. Here are the most common causes.

## 1. Audience Mismatch

The `Audience` in your JWT bearer configuration must match the `aud` claim in the token. If your IdentityServer issues tokens with a specific audience value, make sure your API is configured to accept it:

```csharp
options.Audience = "api1"; // Must match what the token contains
```

Decode your JWT (e.g., at jwt.io) and check the `aud` claim matches exactly.

## 2. Issuer Mismatch

The token's `iss` claim must match the `Authority` URL. Common issues:
- Trailing slashes: `https://identity.example.com` vs `https://identity.example.com/`
- HTTP vs HTTPS: `http://` vs `https://`
- Different hostnames in different environments

## 3. Token Expiration

Check the `exp` claim in your JWT. If the token has expired, it will be rejected with a 401. Make sure clocks are synchronized between your servers.

## 4. Middleware Ordering

Ensure `UseAuthentication()` comes before `UseAuthorization()` in your middleware pipeline:

```csharp
app.UseAuthentication();  // Must be first
app.UseAuthorization();
```

If these are reversed, authentication never runs and all requests appear anonymous.

## 5. Signing Key Issues

The API needs to be able to download the signing keys from the IdentityServer's JWKS endpoint. If the discovery document or JWKS can't be reached, token validation fails.

## Debugging Steps

- Enable logging at the `Debug` level for `Microsoft.AspNetCore.Authentication`
- Decode the JWT at jwt.io and inspect all claims
- Verify the discovery endpoint is reachable
- Check for clock skew issues
