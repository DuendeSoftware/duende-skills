# Adding Custom Claims to the m2m_client

You can add static claims to a client that will be included in access tokens.

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

    // Remove the prefix so claims appear without 'client_' prefix
    ClientClaimsPrefix = ""
}
```

By default, client claims are prefixed with `client_` (e.g., `client_tenant_id`). Setting `ClientClaimsPrefix` to an empty string removes this prefix.
