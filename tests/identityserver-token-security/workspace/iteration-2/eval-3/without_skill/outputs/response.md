# Setting Up mTLS Client Authentication in IdentityServer

## Configuration

To set up mTLS, you'll need to configure certificate authentication in ASP.NET Core and set up the client:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add certificate authentication
builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
    });

builder.Services.AddIdentityServer()
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "mtls.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" },
            ClientSecrets =
            {
                new Secret("ABC123DEF456")
                {
                    Description = "Client certificate thumbprint"
                }
            }
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

var app = builder.Build();

app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## mTLS Endpoints

For the mTLS subdomain, you'll need to configure your reverse proxy (nginx, YARP, etc.) to require client certificates on the `mtls` subdomain and forward them to IdentityServer.

In your `appsettings.json` or Kestrel configuration:

```csharp
builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.ConfigureHttpsDefaults(https =>
    {
        https.ClientCertificateMode = ClientCertificateMode.AllowCertificate;
    });
});
```

## Notes

- The client presents its certificate during the TLS handshake
- The certificate thumbprint is matched against the client's registered secret
- mTLS provides strong client authentication since it requires possession of the private key
- You'll need to set up proper certificate infrastructure (CA, certificate distribution, renewal)
