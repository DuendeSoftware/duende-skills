# Enabling DPoP for `dpop_client`

DPoP (Demonstrating Proof-of-Possession) is supported in Duende IdentityServer and can be required on a specific client. Here's the configuration for a client credentials client that keeps its shared secret while requiring DPoP, with a 2-minute clock skew.

## Client configuration

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Require Proof-of-Possession using DPoP
    RequireDPoP = true,

    // Allow up to 2 minutes of clock skew when validating the DPoP proof
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

You can drop this into your `Config.Clients` list next to the existing `machine_client`. The important part is that requiring DPoP does not change how the client authenticates — it still uses the client credentials grant with the hashed shared secret. DPoP is layered on top of that.

## What DPoP does

Normally, OAuth access tokens are **bearer tokens**: whoever holds the token can use it, so a leaked or stolen token can be replayed by an attacker.

DPoP makes the token **sender-constrained**. The flow is:

1. The client creates a public/private key pair (represented as a JSON Web Key, JWK).
2. When requesting a token, it sends a signed **DPoP proof JWT** in the `DPoP` HTTP header.
3. IdentityServer binds the issued access token to that key by adding a `cnf` (confirmation) claim containing a `jkt` value — the SHA-256 thumbprint of the client's public JWK:

   ```json
   { "cnf": { "jkt": "<base64url-encoded JWK thumbprint>" } }
   ```

4. On every call to a protected API, the client must again send a DPoP proof JWT signed with the same private key. The API checks that the proof's key matches the `jkt` in the token.

Because the attacker would also need the client's private key to produce a valid proof, a stolen access token alone is useless. The proof also includes the HTTP method and URL plus an `iat` timestamp (the reason for the clock-skew setting) to prevent replay.

## Notes

- DPoP is a licensed/commercial feature in Duende IdentityServer, so make sure your license tier includes it.
- Your APIs must also be configured to validate DPoP proofs, otherwise they will treat the token as an ordinary bearer token.
