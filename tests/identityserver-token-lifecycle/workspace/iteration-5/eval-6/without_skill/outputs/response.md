# Adding Custom Client Claims to `m2m_client`

You can attach static claims to a client using the `Claims` collection with `ClientClaim` entries. By default IdentityServer adds a `client_` prefix to these claims in the token; to emit them without the prefix, set `ClientClaimsPrefix` to an empty string.

## Updated client

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

## Explanation

- `Claims = { new ClientClaim("tenant_id", "42"), new ClientClaim("department", "billing") }` adds the two custom claims to every access token this client obtains.
- `ClientClaimsPrefix = ""` removes the default `client_` prefix, so the claims show up as `tenant_id` and `department` rather than `client_tenant_id` and `client_department`.

Since this is a client-credentials client, the claims are included in its access tokens automatically.
