# Adding Client Claims to m2m_client

To add custom claims to the machine-to-machine client's access tokens, you'll need to configure claims on the client and adjust the prefix.

```csharp
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },
    
    // Add custom claims
    Claims = new List<Claim>
    {
        new Claim("tenant_id", "42"),
        new Claim("department", "billing")
    },
    
    // Remove the default prefix
    ClientClaimsPrefix = ""
}
```

## Key Changes

1. **Claims collection** — Added two claims: `tenant_id` with value `42` and `department` with value `billing`.

2. **`ClientClaimsPrefix = ""`** — By default, IdentityServer prefixes client claims with `client_`. Setting this to empty string removes the prefix.

3. Since this is a `client_credentials` flow, the client claims should automatically be included in the access token without needing additional configuration.
