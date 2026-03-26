# Setting Up mTLS Client Authentication

To configure mutual TLS authentication, you need to enable mTLS in IdentityServer and configure certificate validation.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
    });

builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls";
})
    .AddMutualTlsSecretValidators()
    .AddInMemoryClients(new[]
    {
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "mtls.client",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" },
            ClientSecrets =
            {
                new Duende.IdentityServer.Models.Secret("ABC123DEF456")
                {
                    Type = "X509Thumbprint"
                }
            }
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

The mTLS subdomain means the token endpoint will be at `https://mtls.yourdomain.com/connect/token`.
