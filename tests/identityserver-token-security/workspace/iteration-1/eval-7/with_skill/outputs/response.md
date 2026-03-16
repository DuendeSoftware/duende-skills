# mTLS Token Binding Without Certificate-Based Client Authentication

You can bind access tokens to a client certificate (via the `cnf` claim) without using the certificate for client authentication. The client authenticates with a shared secret as usual, but the TLS client certificate presented during the token request is used to embed the `x5t#S256` (SHA-256 certificate thumbprint) in the access token's `cnf` claim.

## Server Configuration

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";

    // Emit the cnf claim for ALL clients that present a TLS client certificate,
    // regardless of whether the certificate is used for client authentication
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

            // Standard shared secret authentication — NOT certificate-based
            ClientSecrets = { new Secret("hybrid_secret".Sha256()) }
        }
    ];
}
```

## How It Works

1. The client establishes a TLS connection to the mTLS token endpoint (`https://mtls.identity.example.com/connect/token`) and presents a client certificate during the TLS handshake.
2. The client authenticates using its shared secret (via POST body or Authorization header) — the certificate is **not** used for authentication.
3. Because `AlwaysEmitConfirmationClaim = true`, IdentityServer reads the SHA-256 thumbprint of the TLS client certificate and embeds it in the access token:

```json
{
  "iss": "https://identity.example.com",
  "client_id": "hybrid_app",
  "cnf": {
    "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2"
  }
}
```

4. When calling the API, the client must use the **same certificate** to establish the TLS connection. The API validates that the `x5t#S256` value in the `cnf` claim matches the SHA-256 thumbprint of the TLS client certificate on the current connection.

## Important: Client Must Present a Certificate

Even though the certificate is not used for client authentication, the client **must** present a TLS client certificate when calling the token endpoint. This is how IdentityServer obtains the thumbprint to embed in the `cnf` claim. Without a certificate on the TLS channel, there is nothing to bind to.

The client can generate a self-signed certificate for this purpose — it doesn't need to be trusted by the server or registered as a client secret.

## API-Side Validation

The API needs custom middleware to validate the `cnf` claim:

```csharp
app.UseAuthentication();
app.UseConfirmationValidation(); // custom middleware to validate cnf against TLS cert
app.UseAuthorization();
```

The middleware extracts the `x5t#S256` from the `cnf` claim in the access token, computes the SHA-256 thumbprint of the TLS client certificate, and rejects the request if they don't match.

## Key Points

- `AlwaysEmitConfirmationClaim = true` is the critical setting. Without it, the `cnf` claim is only emitted when the certificate is used for client authentication.
- This pattern works with any client authentication method: shared secrets, private_key_jwt, etc.
- The client certificate can be self-signed and ephemeral — it only needs to be consistent between the token request and API calls.
