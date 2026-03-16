# Adding Client Claims to m2m_client

To add custom claims to the m2m_client's access tokens:

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Add client claims
    Claims =
    {
        new ClientClaim("tenant_id", "42"),
        new ClientClaim("department", "billing")
    },

    // Remove the default prefix
    ClientClaimsPrefix = "",

    // Ensure claims are always sent
    AlwaysSendClientClaims = true
}
```

This adds `tenant_id` with value `42` and `department` with value `billing` to every access token issued for this client. Setting `ClientClaimsPrefix` to an empty string ensures the claims appear without any prefix.
