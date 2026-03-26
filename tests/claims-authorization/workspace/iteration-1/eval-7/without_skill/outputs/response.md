# Adding Claims to Client Credentials Tokens

To add static claims to a client credentials client, you can configure them in the client definition.

```csharp
new Client
{
    ClientId = "billing-service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },
    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    },
    ClientClaimsPrefix = ""
}
```

Setting `ClientClaimsPrefix` to an empty string removes the default `client_` prefix, so the claims appear directly as `customer_id` and `region` in the token.
