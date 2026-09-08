# Binding tokens to a client certificate without certificate authentication

You want `hybrid_app` to keep authenticating with its shared secret, but still have IdentityServer stamp a certificate confirmation (`cnf`) claim into the access token so the token is sender-constrained to a client certificate. These are two independent things: *how the client authenticates* vs. *how the token is bound*.

## Client configuration — keep the shared secret

The client stays exactly as a normal client-credentials client with a hashed shared secret. Do **not** add an X.509 certificate secret, because the certificate is not being used to authenticate the client:

```csharp
new Client
{
    ClientId = "hybrid_app",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },
    ClientSecrets = { new Secret("hybrid_secret".Sha256()) } // shared secret only
}
```

## Server configuration

Enable mutual TLS support so IdentityServer inspects the client certificate on the TLS channel and can attach it to the token:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## How the binding works

When the client establishes the TLS connection to the token endpoint and presents a client certificate, IdentityServer can add a confirmation claim to the issued access token containing the SHA-256 thumbprint of that certificate:

```json
{
  "cnf": { "x5t#S256": "<base64url SHA-256 thumbprint of the client cert>" }
}
```

Downstream APIs then compare that `x5t#S256` value against the certificate on the incoming TLS connection. Even though the token itself is a normal JWT, it can only be used by a caller that also presents the matching certificate — so a leaked token is not enough to call the API.

## Key points

- The client must **present a TLS client certificate when calling the token endpoint**, even though the certificate is not used to authenticate it. Without a certificate on the channel there is nothing to bind.
- Authentication (shared secret) and token binding (certificate `cnf`) are completely separate concerns, which is exactly what you asked for.
- Your APIs must validate the `cnf` claim against the presented client certificate for the binding to actually be enforced.
