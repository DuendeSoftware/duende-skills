# Enabling DPoP for `dpop_client`

## What DPoP does
DPoP (Demonstrating Proof-of-Possession, RFC 9449) sender-constrains tokens. The client holds a private key and sends a signed *proof JWT* in a `DPoP` header with each token request and API call. IdentityServer binds the access token to the proof key's thumbprint (`cnf.jkt` claim). A stolen token is useless without the private key, and proofs are tied to HTTP method, URL, and a time (`iat`), so they can't easily be replayed.

## Client configuration

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    RequireDPoP = true,                       // token requests must carry a DPoP proof
    DPoPClockSkew = TimeSpan.FromMinutes(2),  // allowed clock skew for proof iat
    DPoPValidationMode = DPoPTokenExpirationValidationMode.Iat // validate iat (Nonce is the alternative)
}
```

Add it to `Config.Clients` in `Program.cs`. Shared secret authentication continues to work; DPoP is an additional proof layer.

Notes:
- With `DPoPValidationMode = Nonce`, the server issues nonces (`DPoP-Nonce` header) and the client must echo them, which removes dependence on clock skew; `Iat` and `Nonce` can be combined (`Iat | Nonce`).
- The API must also validate DPoP tokens (the `cnf` claim and proof header); otherwise the binding isn't enforced.
- Client side must generate a key (e.g. RSA/EC JWK) and send a proof with each request.
