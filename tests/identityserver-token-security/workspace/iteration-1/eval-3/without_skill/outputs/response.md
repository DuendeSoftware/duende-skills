# Setting Up mTLS Client Authentication

Mutual TLS (mTLS) allows clients to authenticate using X.509 certificates. IdentityServer validates the client certificate presented during the TLS handshake and can use it for client authentication at the token endpoint.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;

    // Configure mTLS endpoints on the 'mtls' subdomain
    options.MutualTls.DomainName = "mtls";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Add mTLS secret validators
idsvrBuilder.AddMutualTlsSecretValidators();

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
            ClientId = "mtls.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" },
            ClientSecrets =
            {
                new Secret("ABC123DEF456", "mtls.thumbprint")
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateThumbprint
                }
            }
        }
    ];
}
```

## How It Works

1. The client presents its X.509 certificate during the TLS handshake when connecting to `https://mtls.identity.example.com/connect/token`.
2. IdentityServer extracts the certificate and compares its thumbprint against the registered `ClientSecrets`.
3. If the thumbprint matches, the client is authenticated and the token request proceeds.
4. The mTLS subdomain (`mtls`) hosts the same IdentityServer endpoints but requires client certificates at the TLS layer.

## Secret Types

- `SecretTypes.X509CertificateThumbprint` — Match by certificate SHA-1 thumbprint (self-issued certs)
- `SecretTypes.X509CertificateName` — Match by certificate distinguished name (PKI certs)

Your reverse proxy (NGINX, IIS, etc.) must be configured to require client certificates on the `mtls` subdomain and forward the certificate to IdentityServer.
