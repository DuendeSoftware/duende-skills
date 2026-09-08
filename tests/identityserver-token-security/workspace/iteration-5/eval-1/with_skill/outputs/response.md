# Enabling DPoP for `dpop_client`

## Client configuration

DPoP is enforced on a per-client basis with `RequireDPoP = true`. The clock skew that controls how the `iat` claim of the DPoP proof token is validated is set with `DPoPClockSkew`. Note that DPoP is completely separate from **client authentication** — the client still authenticates with its shared secret over the client credentials flow.

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "dpop_client",

    // Client authentication is unchanged — a plain shared secret over client credentials.
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
    ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Turn on Proof-of-Possession via DPoP for this client.
    RequireDPoP = true,

    // Control the clock skew used when validating the DPoP proof token's `iat` claim.
    DPoPClockSkew = TimeSpan.FromMinutes(2)

    // (Optional) DPoPValidationMode defaults to DPoPTokenExpirationValidationMode.Iat
}
```

Dropping this into the existing `Config.Clients` collection in `Program.cs`:

```csharp
public static IEnumerable<Duende.IdentityServer.Models.Client> Clients =>
[
    new Duende.IdentityServer.Models.Client
    {
        ClientId = "machine_client",
        AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
        ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
        AllowedScopes = { "api1" }
    },
    new Duende.IdentityServer.Models.Client
    {
        ClientId = "dpop_client",
        AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
        ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
        AllowedScopes = { "api1" },
        RequireDPoP = true,
        DPoPClockSkew = TimeSpan.FromMinutes(2)
    }
];
```

## What DPoP does

**DPoP (Demonstrating Proof-of-Possession at the application layer)** turns an ordinary bearer access token into a **sender-constrained** token. By default, OAuth access tokens are bearer tokens — anyone who steals the token can use it. DPoP binds the token to an asymmetric key that only the legitimate client holds.

How it works:

1. The client generates an asymmetric key pair, stored as a **JWK**.
2. When it requests a token, IdentityServer embeds a `cnf` (confirmation) claim into the access token containing the **`jkt`** value — the base64url-encoded SHA-256 **JWK thumbprint** of the client's public key:

   ```json
   {
     "cnf": {
       "jkt": "JGSVlE73oKtQQI1dypYg8_JNat0xJjsQNyOI5oxaZf4"
     }
   }
   ```

3. On **every** request to the token endpoint and to protected APIs, the client proves it possesses the matching private key by signing a short-lived **DPoP proof JWT** and sending it in the `DPoP` HTTP request header. The API recomputes the thumbprint of the key in the proof and checks it matches the `jkt` in the token's `cnf` claim.

Because a stolen token is useless without the private key that produced the matching proof, DPoP protects against token replay/exfiltration. Replay of the proof itself is mitigated by the `iat` timestamp (validated within `DPoPClockSkew`) and an optional server-issued nonce.

## Edition and version requirements

DPoP requires **Duende IdentityServer Enterprise Edition** and **version 6.3 or later**. Your project targets IdentityServer 8.0, which supports it. Enforcing DPoP requires no changes to how the client authenticates — the shared secret continues to prove *client identity* at the token endpoint, while DPoP independently proves *possession of the token* on every call.
