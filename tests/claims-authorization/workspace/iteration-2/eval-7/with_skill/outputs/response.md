# Client Claims for billing-service

To add static claims to a client credentials flow client and remove the default `client_` prefix:

```csharp
var client = new Client
{
    ClientId = "billing-service",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "invoicing.api" },

    // Static claims emitted into access tokens
    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    },

    // Remove the default "client_" prefix — claims appear as "customer_id" and "region"
    ClientClaimsPrefix = ""
};
```

## Key Points

- **`Claims`** accepts `ClientClaim` objects (not `Claim` from `System.Security.Claims`). Each `ClientClaim` takes a type and value.
- **`ClientClaimsPrefix`** defaults to `"client_"`. Without setting it to `""`, your claims would appear as `client_customer_id` and `client_region` in the token. Setting it to an empty string removes the prefix.
- **Client claims are only emitted in the client credentials flow** by default. For other flows (authorization code, hybrid, etc.), you must also set `AlwaysSendClientClaims = true` on the client definition.
- For dynamic client claims that vary at runtime (not static), implement `ICustomTokenRequestValidator` instead.
