# Adding static claims to the `billing-service` access tokens

For a client-credentials client, you can attach fixed claims directly to the `Client` definition using its `Claims` collection with `ClientClaim` entries. By default those claims get a `client_` prefix in the token; you can turn that off with `ClientClaimsPrefix`.

## Client definition

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
        new ClientClaim("region", "us-east"),
    },

    // Emit the claims without the default "client_" prefix
    ClientClaimsPrefix = ""
}
```

With `ClientClaimsPrefix = ""`, the token will contain `customer_id` and `region` rather than `client_customer_id` and `client_region`.

## Slotting it into your config

```csharp
public static IEnumerable<Client> Clients =>
[
    // existing m2m.client ...

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
            new ClientClaim("region", "us-east"),
        },
        ClientClaimsPrefix = ""
    },

    // existing interactive client ...
];
```

## Notes

- `ClientClaim` takes a type and value (and optionally a value type), just like a regular `Claim`.
- The `client_` prefix exists to avoid collisions with user claims. Since this is a machine-to-machine client with no user, clearing the prefix is safe here.
- The two claims are static, so they'll be present on every token issued to `billing-service`.
