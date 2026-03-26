# Setting Up mTLS Client Authentication

Mutual TLS (mTLS) allows clients to authenticate using X.509 certificates. IdentityServer validates the certificate and can also bind access tokens to the certificate via the `cnf` claim.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.Certificate;

var builder = WebApplication.CreateBuilder(args);

// Certificate authentication scheme
builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
        options.ValidateCertificateUse = true;
    });

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;

    // mTLS endpoints on the 'mtls' subdomain
    options.MutualTls.DomainName = "mtls";

    // Reference the certificate authentication scheme
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
});

// Add mTLS secret validators
idsvrBuilder.AddMutualTlsSecretValidators();

idsvrBuilder
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "mtls.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" },
            ClientSecrets =
            {
                // Authenticate by certificate thumbprint
                new Secret("ABC123DEF456", "mtls.thumbprint")
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateThumbprint
                }
            }
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## How mTLS Authentication Works

1. **TLS Handshake**: The client presents its X.509 certificate during the TLS handshake
2. **Certificate Authentication**: ASP.NET Core's `AddCertificate` middleware validates the certificate
3. **Secret Validation**: IdentityServer's mTLS secret validator compares the certificate's thumbprint against the client's configured `X509CertificateThumbprint` secret
4. **Token Endpoint**: The client calls the mTLS token endpoint at `https://mtls.yourdomain.com/connect/token`

## mTLS Subdomain

Setting `MutualTls.DomainName = "mtls"` creates mTLS-specific endpoints on a subdomain. For example, if your IdentityServer is at `https://identity.example.com`, the mTLS endpoints will be at `https://mtls.identity.example.com`. This separation allows your reverse proxy or load balancer to require client certificates only on the mTLS subdomain.

## Secret Types

- **`X509CertificateThumbprint`**: Matches the SHA-1 thumbprint of the certificate. Good for self-issued certificates.
- **`X509CertificateName`**: Matches the certificate's distinguished name (CN). Good for PKI-issued certificates.
