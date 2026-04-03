# Troubleshooting 401 Unauthorized

Common causes when JWT validation fails:

## 1. Authority Mismatch
Make sure the `Authority` URL matches your IdentityServer exactly. The JWT bearer handler fetches the discovery document from this URL.

## 2. Audience Mismatch
The `Audience` must match what the token's `aud` claim contains. Check your IdentityServer configuration to see what audience is set in the token.

## 3. Token Expiration
The token might be expired. Check the `exp` claim in the JWT.

## 4. HTTPS Issues
In development, you may need `options.RequireHttpsMetadata = false` if you're running without HTTPS.

## 5. Middleware Order
Ensure `UseAuthentication()` is called before `UseAuthorization()`:

```csharp
app.UseAuthentication();
app.UseAuthorization();
```

## 6. Signing Key
The API downloads the public key from the IdentityServer's JWKS endpoint. If key rotation happened and your API cached the old key, it might reject new tokens.

Try checking the JWT content at jwt.io to see the actual claims and compare them with your API configuration.
