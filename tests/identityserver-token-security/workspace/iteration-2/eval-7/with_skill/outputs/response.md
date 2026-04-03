# mTLS Token Binding Without Certificate Authentication

You can bind access tokens to a client certificate without using the certificate for client authentication. The client authenticates normally (e.g., with a shared secret) but the access token's `cnf` claim will contain the SHA-256 thumbprint of the TLS client certificate.

## IdentityServer Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;
    
    // Emit the cnf claim even when the certificate isn't used for client authentication
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
    
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "hybrid_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            
            // Standard shared secret authentication — NOT certificate-based
            ClientSecrets = { new Secret("secret".Sha256()) },
            
            RedirectUris = { "https://hybrid.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" }
        }
    });

idsvrBuilder.AddMutualTlsSecretValidators();

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

1. The client authenticates at the token endpoint using its **shared secret** (standard `client_secret_post` or `client_secret_basic`).
2. The client also presents a **TLS client certificate** when connecting to the mTLS token endpoint.
3. Because `AlwaysEmitConfirmationClaim = true`, IdentityServer reads the certificate from the TLS channel and embeds its SHA-256 thumbprint in the access token's `cnf` claim:

```json
{
  "cnf": {
    "x5t#S256": "bwcK0esc3ACC3DB2Y5_lESsXE8o9ltc05O89jdN-dg2"
  }
}
```

4. When the client calls an API, it must use the **same certificate** to establish the TLS connection.
5. The API validates the `cnf` claim's `x5t#S256` value against the SHA-256 thumbprint of the client certificate on the TLS channel.

## Key Point

The client **must use a TLS client certificate** when calling the token endpoint, even though the certificate is not used for authentication. The certificate is only used to compute the thumbprint that gets embedded in the `cnf` claim. Authentication is handled separately by the shared secret.

This pattern is useful when:
- You want sender-constrained tokens but the client already has a different authentication mechanism
- You're migrating to mTLS gradually — start with token binding, then later switch to certificate-based authentication
- You have public clients that can generate ephemeral certificates for token binding
