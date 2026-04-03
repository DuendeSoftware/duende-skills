# Adding Client Claims to m2m_client

To add custom claims to the `m2m_client` access tokens without the default `client_` prefix, update the client configuration:

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Client claims embedded in access tokens
    Claims =
    {
        new ClientClaim("tenant_id", "42"),
        new ClientClaim("department", "billing")
    },

    // Remove the default 'client_' prefix so claims appear as-is
    ClientClaimsPrefix = ""
}
```

## Key Changes

1. **`Claims` collection with `ClientClaim` entries** — Two `ClientClaim` objects are added:
   - `new ClientClaim("tenant_id", "42")` — adds a `tenant_id` claim with value `42`
   - `new ClientClaim("department", "billing")` — adds a `department` claim with value `billing`

2. **`ClientClaimsPrefix = ""`** — By default, Duende IdentityServer prefixes client claims with `client_` (e.g., `client_tenant_id`). Setting this to an empty string removes the prefix, so the claims appear as `tenant_id` and `department` directly in the access token.

3. **No need for `AlwaysSendClientClaims`** — Since `m2m_client` uses `GrantTypes.ClientCredentials`, client claims are automatically included in access tokens for this flow. `AlwaysSendClientClaims` is only needed if you want client claims in tokens from other flows (like authorization code).

## Full Updated Program.cs (m2m_client section)

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },
    Claims =
    {
        new ClientClaim("tenant_id", "42"),
        new ClientClaim("department", "billing")
    },
    ClientClaimsPrefix = ""
}
```

The resulting access token will contain:
```json
{
  "client_id": "m2m_client",
  "tenant_id": "42",
  "department": "billing",
  "scope": "api1",
  ...
}
```
