# Adding Prefix-Free Client Claims to `m2m_client`

Client claims are defined per-client via the `Claims` collection (each entry a `ClientClaim`). By default IdentityServer prefixes them with `client_` in the access token (e.g. `client_tenant_id`). Setting `ClientClaimsPrefix = ""` removes that prefix so the claims appear as `tenant_id` and `department`.

For a **client_credentials** client, client claims are already emitted by default — so you do **not** need `AlwaysSendClientClaims = true` here (that flag exists to force client claims into flows that carry a user, like authorization code).

## Updated `m2m_client`

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Custom client claims, emitted without the default "client_" prefix
    Claims =
    {
        new ClientClaim("tenant_id", "42"),
        new ClientClaim("department", "billing")
    },
    ClientClaimsPrefix = "" // remove the default "client_" prefix
}
```

## Result in the access token

```json
{
  "client_id": "m2m_client",
  "scope": "api1",
  "tenant_id": "42",
  "department": "billing"
}
```

> If you had left `ClientClaimsPrefix` at its default, these would appear as `client_tenant_id` and `client_department`. Setting it to an empty string yields the unprefixed names you want. Watch for collisions with existing user/standard claim types when you drop the prefix.
