# Client Credentials Claims Without Prefix

To add static claims to a client credentials client and remove the default `client_` prefix, configure the `Client` object with `Claims` and set `ClientClaimsPrefix` to an empty string.

## Updated Client Configuration

```csharp
public static IEnumerable<Client> Clients =>
[
    new Client
    {
        ClientId = "billing-service",
        ClientName = "Billing Service",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret("billing-secret".Sha256()) },
        AllowedScopes = { "api1" },

        // Static claims attached to the client
        Claims =
        {
            new ClientClaim("customer_id", "acme-corp"),
            new ClientClaim("region", "us-east"),
        },

        // Remove the default "client_" prefix from claim names
        // Without this, claims would appear as "client_customer_id" and "client_region"
        ClientClaimsPrefix = "",
    },
    // ... other clients
];
```

## How It Works

- **`Claims`**: A collection of `ClientClaim` objects. These are static claims attached to the client definition and emitted into access tokens.
- **`ClientClaimsPrefix`**: By default, client claims are prefixed with `client_` to prevent collision with user claims. Setting it to `""` removes the prefix so claims appear as `customer_id` and `region` directly.
- **`GrantTypes.ClientCredentials`**: Client claims are emitted by default only in the client credentials flow, since there's no user involved. For other grant types (authorization code, etc.), you would need to set `AlwaysSendClientClaims = true` on the client to include client claims alongside user claims.

## Resulting Access Token Claims

```json
{
  "iss": "https://identity.example.com",
  "client_id": "billing-service",
  "scope": "api1",
  "customer_id": "acme-corp",
  "region": "us-east",
  "exp": 1711468800,
  "iat": 1711465200
}
```
