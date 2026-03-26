# mTLS Token Binding Without Certificate Auth

To bind tokens to a certificate without using the certificate for authentication, configure IdentityServer to always emit the confirmation claim.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.AlwaysEmitConfirmationClaim = true;
})
    .AddInMemoryClients(new[]
    {
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "hybrid_app",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
            ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
            RedirectUris = { "https://hybrid.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" }
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

When `AlwaysEmitConfirmationClaim` is true, the access token includes a `cnf` claim with the `x5t#S256` thumbprint of the client's TLS certificate, even though the certificate isn't used for client authentication. The client authenticates normally with its shared secret. The client still needs to present a TLS certificate when calling the token endpoint for the binding to work.
