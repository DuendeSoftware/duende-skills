# mTLS Token Binding Without Certificate Authentication

You can use mTLS to bind tokens to a client certificate (`cnf` claim with `x5t#S256`) without using the certificate for client authentication. This means the client authenticates normally (e.g., shared secret) but the access token is cryptographically bound to the TLS client certificate.

## Configuration

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;

    // Emit cnf claim even when the certificate isn't used for client authentication
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
});

idsvrBuilder
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "hybrid_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // Standard shared secret authentication
            ClientSecrets = { new Secret("hybrid_secret".Sha256()) },

            RedirectUris = { "https://hybrid.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

1. **Client authentication**: `hybrid_app` authenticates with its shared secret at the token endpoint (standard `client_secret_post` or `client_secret_basic`)

2. **TLS client certificate**: The client must present a TLS client certificate when calling the token endpoint, even though the certificate is not used for authentication

3. **Token binding**: IdentityServer takes the SHA-256 thumbprint of the TLS client certificate and embeds it in the access token via the `cnf` claim:
   ```json
   {
     "cnf": {
       "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2"
     }
   }
   ```

4. **API validation**: The API validates that the `x5t#S256` value in the `cnf` claim matches the thumbprint of the TLS client certificate presented by the caller

## Key Setting: `AlwaysEmitConfirmationClaim`

Without `AlwaysEmitConfirmationClaim = true`, the `cnf` claim is only embedded when the certificate is used for **client authentication** (via `X509CertificateThumbprint` or `X509CertificateName` secrets). With it set to `true`, the `cnf` claim is embedded whenever a TLS client certificate is present, regardless of the authentication method.

## Why Use This Pattern?

- You want proof-of-possession token security without the complexity of certificate-based client authentication
- The client can use any authentication method (shared secret, private_key_jwt) while still getting sender-constrained tokens
- Works well with public clients that can create self-signed certificates dynamically
