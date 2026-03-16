# Adding Claims to a Client Credentials Client

You can add static claims to a client by configuring the `Claims` property on the client definition:

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
    }
}
```

By default, IdentityServer prefixes client claims with `client_`, so the claims would appear as `client_customer_id` and `client_region` in the token. To remove this prefix, set `ClientClaimsPrefix` to an empty string:

```csharp
ClientClaimsPrefix = ""
```

This will ensure the claims appear as `customer_id` and `region` directly in the access token.
