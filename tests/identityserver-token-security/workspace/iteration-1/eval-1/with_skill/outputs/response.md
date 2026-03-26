# Enabling DPoP for the dpop_client

DPoP (Demonstrating Proof-of-Possession) binds access tokens to an asymmetric key held by the client via the `cnf` claim, specifically using a `jkt` (JWK Thumbprint) value. This prevents stolen tokens from being used by attackers who don't possess the private key.

## Client Configuration

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Enable DPoP - tokens will be bound to the client's proof key
    RequireDPoP = true,

    // Control clock skew for DPoP proof token validation
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

## How DPoP Works

1. **Token Request**: The client generates an asymmetric key pair (e.g., RSA or ECDSA) and sends a signed DPoP proof JWT via the `DPoP` HTTP header when requesting a token from the token endpoint.

2. **Token Binding**: IdentityServer validates the proof and embeds the key's thumbprint in the access token via the `cnf` claim:
   ```json
   {
     "cnf": {
       "jkt": "JGSVlE73oKtQQI1dypYg8_JNat0xJjsQNyOI5oxaZf4"
     }
   }
   ```

3. **API Calls**: On every API call, the client sends both the access token (in the `Authorization: DPoP <token>` header) and a fresh DPoP proof JWT (in the `DPoP` header). The API validates that the proof was signed by the same key whose thumbprint is in the `cnf` claim.

4. **Protection**: Even if an attacker steals the access token, they cannot use it without the private key to generate valid DPoP proofs.

## Important Notes

- **DPoP requires Enterprise Edition** of Duende IdentityServer (version >= 6.3)
- **DPoP is separate from client authentication**: The client still authenticates with its shared secret at the token endpoint. DPoP adds proof-of-possession on top — it proves the client presenting the token is the same one that requested it.
- **`DPoPClockSkew`** controls the acceptable time drift when validating the `iat` claim in DPoP proof tokens. The default is 5 minutes; here we've set it to 2 minutes for tighter validation.
- **`DPoPValidationMode`** defaults to `DPoPTokenExpirationValidationMode.Iat`, which validates the proof token's `iat` claim against server time ± clock skew.
