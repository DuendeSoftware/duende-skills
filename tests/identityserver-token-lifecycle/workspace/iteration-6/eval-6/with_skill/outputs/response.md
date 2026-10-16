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
    ClientClaimsPrefix = ""   // default prefix is "client_"
}
```

Access tokens then contain `"tenant_id": "42"` and `"department": "billing"` rather than `client_tenant_id`/`client_department`.

Notes:
- Client claims are sent by default only in the client credentials flow, which is what `m2m_client` uses, so `AlwaysSendClientClaims` isn't needed. (Set it to `true` only if you want them in other flows.)
- With an empty prefix, ensure names don't collide with user claim types (e.g. `sub`, `name`).
- Values are strings; use a `ClaimValueType` (e.g. `ClaimValueTypes.Integer`) if you want `tenant_id` as a number in the JWT.
