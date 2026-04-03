# Client Claims for billing-service

To add static claims to a client credentials client in IdentityServer:

```csharp
var client = new Client
{
    ClientId = "billing-service",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "invoicing.api" },

    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    }
};
```

## Removing the Prefix

By default, IdentityServer prefixes client claims with `client_`. So `customer_id` would appear as `client_customer_id` in the token. To remove this prefix:

```csharp
ClientClaimsPrefix = ""
```

Add this to the client configuration and the claims will appear without the prefix.

## Notes

- Client claims are static and defined at configuration time
- They appear in the access token alongside scope and audience claims
- The `ClientClaim` type takes a claim type string and a value string
- For dynamic claims that change per request, you'd need to use a custom profile service or token endpoint filter
