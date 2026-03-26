# Enabling DPoP for a Client

DPoP (Demonstrating Proof of Possession) adds a layer of security by binding tokens to a cryptographic key.

## Configuration

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },
    RequireDPoP = true,
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

## What DPoP Does

DPoP prevents token replay attacks. The client creates a key pair and sends a proof JWT with each request. The server validates that the token was issued to the holder of the key. The access token includes a `cnf` claim with the `jkt` (JWK Thumbprint) of the client's public key, binding the token to that key.

The client authenticates normally with its shared secret — DPoP is an additional layer on top of client authentication.
