# Replacing AddDeveloperSigningCredential

`AddDeveloperSigningCredential()` is meant for development only. When migrating to Duende IdentityServer, you should replace it with a proper signing key.

## Options

### Use a certificate
```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("cert.pfx", "password"));
```

### Use an RSA key
```csharp
var rsa = RSA.Create();
// Load from secure storage
builder.Services.AddIdentityServer()
    .AddSigningCredential(new RsaSecurityKey(rsa), "RS256");
```

## Production Transition

For your production scenario where existing tokens are already signed, you need to be careful:

1. Keep the old key available for token validation during a transition period
2. Add the new key for new token signing
3. Once old tokens expire, remove the old key

Most OIDC clients will automatically pick up new keys from the discovery document's JWKS endpoint, so as long as you can restart your clients and APIs, they should work with the new key automatically.
