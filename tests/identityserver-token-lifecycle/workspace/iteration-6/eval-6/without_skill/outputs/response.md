Add the claims to `m2m_client` and clear the claim prefix:

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
    ClientClaimsPrefix = ""   // default is "client_"
}
```

Result: the access token contains `"tenant_id": "42"` and `"department": "billing"` instead of `client_tenant_id` / `client_department`.

Notes:
- Client credentials flow always includes client claims. For other flows you'd need `AlwaysSendClientClaims = true`.
- Unprefixed claims could collide with standard or user claims (e.g. `sub`, `name`) — these names are safe.
- The API should still authorize on these values properly; they're client-bound, not user-bound.
