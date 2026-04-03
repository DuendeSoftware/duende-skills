# mTLS Token Binding Without Certificate Authentication

If you want to bind tokens to a client certificate but use a different authentication method, you can configure mTLS for token binding only.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
})
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "hybrid_app",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" }
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

When mTLS is enabled and a client presents a certificate during the TLS handshake, IdentityServer can bind the token to that certificate. The access token will contain a `cnf` claim with the certificate's thumbprint.

The client authenticates with its regular shared secret, but the certificate creates a binding between the token and the TLS channel.

## Notes

- The API must validate that the `cnf` claim matches the client certificate presented in the request
- This provides an additional layer of security beyond bearer tokens
- The certificate can be self-signed for this purpose
- Make sure your infrastructure supports client certificates
