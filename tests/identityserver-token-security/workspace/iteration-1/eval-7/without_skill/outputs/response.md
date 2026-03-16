# mTLS Token Binding Without Certificate Authentication

You can use mTLS to bind tokens to a client certificate without using the certificate for client authentication. The client authenticates normally (e.g., with a shared secret) but the TLS client certificate is used to embed a confirmation claim in the access token.

## Configuration

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";

    // Emit cnf claim even when the certificate is not used for client authentication
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "hybrid_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "https://hybrid.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Standard shared secret — NOT certificate-based authentication
            ClientSecrets = { new Secret("hybrid_secret".Sha256()) }
        }
    ];
}
```

## How It Works

When `AlwaysEmitConfirmationClaim = true`, IdentityServer will embed the `cnf` claim in the access token with the `x5t#S256` value — the SHA-256 thumbprint of the TLS client certificate. This happens regardless of how the client authenticated.

The resulting access token will contain:

```json
{
  "cnf": {
    "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2"
  }
}
```

The API can then validate that the certificate used to call the API matches the thumbprint in the `cnf` claim, ensuring the token hasn't been stolen and replayed from a different TLS connection.

## Key Points

- `AlwaysEmitConfirmationClaim = true` is the key setting — without it, the `cnf` claim is only emitted for certificate-authenticated clients.
- The client still authenticates with its shared secret normally.
- The certificate binding provides proof-of-possession without changing the authentication method.
