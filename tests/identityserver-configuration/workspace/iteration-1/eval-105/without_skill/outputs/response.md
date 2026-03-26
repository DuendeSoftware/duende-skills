# Private Key JWT Client Configuration

To configure a client that authenticates using JWT with a certificate:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp-cert",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets =
            {
                new Secret
                {
                    Type = "X509CertificateBase64",
                    Value = Convert.ToBase64String(cert.RawData)
                }
            },
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            AllowedScopes = { "openid", "profile" }
        }
    });
```

The client will authenticate by sending a signed JWT assertion instead of a shared secret.
