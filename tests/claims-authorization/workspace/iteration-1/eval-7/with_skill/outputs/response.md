# Client Claims for billing-service

To add static claims to a client credentials flow client and remove the default `client_` prefix, configure the `Client` object with `Claims` and `ClientClaimsPrefix`:

```csharp
new Client
{
    ClientId = "billing-service",
    ClientName = "Billing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Static claims emitted in the access token
    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    },

    // Remove the default "client_" prefix so claims appear as
    // "customer_id" and "region" instead of "client_customer_id" and "client_region"
    ClientClaimsPrefix = ""
}
```

## Key Points

- **`ClientClaim`** objects in the `Claims` collection are emitted as static claims in access tokens.
- **`ClientClaimsPrefix`** defaults to `"client_"`. Set it to `""` (empty string) to remove the prefix. Be careful — without a prefix, client claims can collide with user claim names.
- Client claims are emitted **by default only in the client credentials flow**. For other flows (e.g., authorization code, hybrid), you must set `AlwaysSendClientClaims = true` on the client to include them:

```csharp
// Only needed if you want client claims in non-client-credentials flows
AlwaysSendClientClaims = true
```

Since `billing-service` uses `GrantTypes.ClientCredentials`, the claims will appear automatically without needing `AlwaysSendClientClaims`.
