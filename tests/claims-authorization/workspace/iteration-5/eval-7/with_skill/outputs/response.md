# Static client claims for `billing-service` without the `client_` prefix

Static claims attached to a `Client` definition are configured via the `Claims` collection using `ClientClaim` objects. By default IdentityServer prefixes them with `client_` (so they'd appear as `client_customer_id`) to avoid colliding with user claims. Set `ClientClaimsPrefix = ""` to emit them under their bare names.

## Client configuration

```csharp
new Client
{
    ClientId = "billing-service",
    ClientName = "Billing Service",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Static claims baked into every access token for this client
    Claims =
    {
        new ClientClaim("customer_id", "acme-corp"),
        new ClientClaim("region", "us-east"),
    },

    // Remove the default "client_" prefix → emitted as "customer_id" / "region"
    ClientClaimsPrefix = ""
}
```

Dropped into your existing `Config.Clients`:

```csharp
public static IEnumerable<Client> Clients =>
[
    new Client
    {
        ClientId = "m2m.client",
        ClientName = "M2M Client",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret("secret".Sha256()) },
        AllowedScopes = { "api1" }
    },
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
    // ... interactive client unchanged
];
```

## Important behavioral note

Client claims are emitted into access tokens **by default only in the client credentials flow**. `billing-service` uses `GrantTypes.ClientCredentials`, so you're fine — the claims will appear automatically.

If you ever reuse this client for a user-centric flow (e.g. authorization code) and still want the client claims in the token, set `AlwaysSendClientClaims = true`:

```csharp
AlwaysSendClientClaims = true,   // needed to emit client claims outside client credentials flow
```

## Caution on removing the prefix

The `client_` prefix exists to prevent client claims from clashing with user claims of the same type. Since `billing-service` is a machine client with no user, collisions aren't a concern here — but be deliberate about `ClientClaimsPrefix = ""` on clients that also issue user-based tokens.
