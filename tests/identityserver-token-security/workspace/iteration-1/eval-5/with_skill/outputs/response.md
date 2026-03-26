# JWT Secured Authorization Requests (JAR) with RSA Key

JAR packages authorization request parameters inside a signed JWT, making them tamperproof. The client sends this signed JWT as the `request` parameter in the authorize request.

## Client Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    // Require signed request objects (JAR)
    RequireRequestObject = true,

    ClientSecrets =
    {
        // RSA key for verifying request objects (and optionally client authentication via private_key_jwt)
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{\"kty\":\"RSA\",\"e\":\"AQAB\",\"kid\":\"secure_app_key\",\"n\":\"...\"}"
        }
    }
}
```

## How JAR Works

1. **Client builds the request JWT**: The client takes all authorization parameters (response_type, scope, redirect_uri, state, nonce, code_challenge, etc.) and wraps them in a JWT, signed with its private RSA key.

2. **Authorization request**: The client sends:
   ```
   GET /connect/authorize?client_id=secure_app&request=eyJhbGciOiJSUzI1NiIs...
   ```

3. **Server validation**: IdentityServer validates the JWT signature using the client's registered public key (the `JsonWebKey` secret), then extracts the authorization parameters from the JWT payload.

4. **Tamperproof**: Because the parameters are signed, an attacker cannot modify them in transit (e.g., changing the scope or redirect_uri).

## Key Points

### Secret Type
The `IdentityServerConstants.SecretTypes.JsonWebKey` type tells IdentityServer this secret contains a JWK (JSON Web Key) with the client's public key. The `Value` should be the serialized JWK containing the RSA public key components (`kty`, `e`, `n`, `kid`).

Alternatively, you can use `IdentityServerConstants.SecretTypes.X509CertificateBase64`:
```csharp
new Secret
{
    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
    Value = Convert.ToBase64String(cert.Export(X509ContentType.Cert))
}
```

### Shared Key for Authentication and JAR
The same RSA key can be used for both:
- **Client authentication** via `private_key_jwt` at the token endpoint
- **JAR** for signing authorization request objects

This simplifies key management — one key pair serves both purposes.

### Security Benefits
- Authorization parameters cannot be tampered with in the browser
- Protects against parameter injection attacks
- Required or recommended by FAPI 2.0 and other security profiles
