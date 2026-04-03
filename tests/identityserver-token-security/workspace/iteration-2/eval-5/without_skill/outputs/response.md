# Configuring JWT Secured Authorization Requests (JAR)

JAR allows clients to send authorization parameters as a signed JWT, which prevents tampering with the request parameters.

## Client Configuration

```csharp
var client = new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    
    // Require request objects
    RequireRequestObject = true,
    
    // Client authenticates with a shared secret
    ClientSecrets = { new Secret("secret".Sha256()) }
};
```

## How JAR Works

1. The client creates a JWT containing authorization parameters (scope, redirect_uri, etc.)
2. The client signs this JWT with its private key
3. The client sends the signed JWT as a `request` parameter in the authorize request
4. IdentityServer validates the signature and uses the parameters from the JWT

## Registering the Client's Key

The client needs to register its public key with IdentityServer. This is typically done by providing the public key or certificate:

```csharp
ClientSecrets =
{
    new Secret("the-public-key-or-cert") // Register public key for JAR validation
}
```

## Notes

- JAR makes authorization parameters tamperproof since they're signed
- The `request` parameter contains the signed JWT
- Alternatively, `request_uri` can reference a URL where the JWT is hosted
- JAR is defined in RFC 9101
