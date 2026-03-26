# JWT Secured Authorization Requests (JAR)

JAR allows clients to send authorization parameters as a signed JWT, preventing tampering.

## Configuration

```csharp
new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    RequireRequestObject = true,

    ClientSecrets =
    {
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{\"kty\":\"RSA\",\"e\":\"AQAB\",\"kid\":\"key1\",\"n\":\"...\"}"
        }
    }
}
```

JAR wraps the authorization request parameters in a signed JWT. The server validates the signature and extracts the parameters. This makes the authorization parameters tamperproof — an attacker can't modify scope, redirect_uri, or other parameters in transit.

The RSA key registered here can also be used for `private_key_jwt` client authentication at the token endpoint, so the same key handles both JAR and client auth.
