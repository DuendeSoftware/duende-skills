# Configuring JWT Secured Authorization Requests (JAR)

JAR wraps authorization request parameters in a signed JWT, making them tamperproof. This prevents attackers from modifying scope, redirect_uri, or other parameters in the browser redirect.

## Server-Side Client Configuration

```csharp
var client = new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    
    // Require signed request objects (JAR)
    RequireRequestObject = true,
    
    // Register the client's public key for verifying request object signatures
    ClientSecrets =
    {
        new Secret
        {
            // RSA key as JWK
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{\"e\":\"AQAB\",\"kid\":\"secure_app_key\",\"kty\":\"RSA\",\"n\":\"...\"}"
        }
    }
};
```

## How the Client Signing Key Works

The client's signing key is registered in `ClientSecrets` using one of two secret types:

### Option A: JSON Web Key (`JsonWebKey`)

```csharp
new Secret
{
    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
    Value = "<JWK JSON string with the public key>"
}
```

The `Value` is a JSON-serialized JWK containing the public key. The client holds the corresponding private key to sign request objects.

### Option B: X.509 Certificate (`X509CertificateBase64`)

```csharp
new Secret
{
    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
    Value = Convert.ToBase64String(cert.Export(X509ContentType.Cert))
}
```

The `Value` is the base64-encoded X.509 certificate (public part only).

## Key Sharing Between Client Authentication and JAR

The same key can be shared between **client authentication** (`private_key_jwt`) and **signed authorization requests** (JAR). This simplifies key management — the client uses one key pair for both proving its identity at the token endpoint and signing authorization request parameters.

When the client authenticates using `private_key_jwt`, it signs a client assertion JWT with its private key. When it uses JAR, it signs the request object JWT with the same private key. IdentityServer verifies both using the registered public key in `ClientSecrets`.

## What JAR Provides

1. **Tamperproof parameters**: The authorization request parameters (scope, redirect_uri, state, nonce, etc.) are signed. Any modification by a man-in-the-middle invalidates the signature.
2. **Front-channel client authentication**: The signed request object proves the request came from the legitimate client.
3. **Confidentiality** (optional): Request objects can also be encrypted (JWE), though this is less common.
4. **Compliance**: JAR is required or recommended by security profiles like FAPI 2.0.
