# Adding Client Claims to m2m_client

Here's how to add `tenant_id` and `department` claims to the `m2m_client` without the default `client_` prefix:

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Client claims
    Claims =
    {
        new ClientClaim("tenant_id", "42"),
        new ClientClaim("department", "billing")
    },

    // Remove the default 'client_' prefix
    ClientClaimsPrefix = ""
}
```

By default, client claims are prefixed with `client_` (e.g., `client_tenant_id`). Setting `ClientClaimsPrefix = ""` removes this prefix so the claims appear as `tenant_id` and `department` directly in the access token.

For client credentials flow, client claims are sent by default — you don't need to set `AlwaysSendClientClaims = true`. That property is only needed when you want client claims emitted in flows that involve user authentication (authorization code, hybrid, etc.).
