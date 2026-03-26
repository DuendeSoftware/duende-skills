# Adding Client Claims to m2m_client

Client claims are static claims defined on the client that get embedded into access tokens. For client credentials flow, they are included by default.

## Updated m2m_client Configuration

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

## How It Works

### ClientClaimsPrefix

By default, Duende IdentityServer prefixes all client claims with `client_` to avoid collisions with user claims. For example, a claim named `tenant_id` would appear as `client_tenant_id` in the access token.

Setting `ClientClaimsPrefix = ""` removes this prefix, so the claims appear exactly as defined:
- `tenant_id` = `"42"`
- `department` = `"billing"`

### AlwaysSendClientClaims

You might wonder about `AlwaysSendClientClaims`. For client credentials flow (`GrantTypes.ClientCredentials`), client claims are **always included** in the access token by default — there's no user context to conflict with. The `AlwaysSendClientClaims` property only matters for interactive flows (authorization code, hybrid) where you want client claims included alongside user claims.

### Resulting Access Token Claims

The JWT access token will contain:

```json
{
    "iss": "https://localhost:5001",
    "client_id": "m2m_client",
    "scope": "api1",
    "tenant_id": "42",
    "department": "billing",
    "exp": 1609936401,
    "iat": 1609932801
}
```
