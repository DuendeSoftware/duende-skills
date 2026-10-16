# Static claims for `billing-service`

```csharp
new Client
{
    ClientId = "billing-service",
    ClientName = "Billing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east")
    },

    ClientClaimsPrefix = ""      // default is "client_"
}
```

By default, client claims are emitted as `client_customer_id` and `client_region`. Setting `ClientClaimsPrefix = ""` removes the prefix, giving `customer_id` and `region`.

Notes:
- In client credentials flow, client claims are always included. For other flows you'd need `AlwaysSendClientClaims = true`.
- Don't pick names colliding with reserved/standard claims.
- Do you need the claim declared as `UserClaims`? Client claims added for client credentials are not filtered by scopes.
- If using the database stores (EF), add them in the ClientClaims table and a migration.
- Verify with a token request and decode at jwt.io.
