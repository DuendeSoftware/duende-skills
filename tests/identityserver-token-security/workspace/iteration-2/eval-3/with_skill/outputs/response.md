# Setting Up mTLS Client Authentication

## IdentityServer Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS
    options.MutualTls.Enabled = true;
    
    // mTLS endpoints on the 'mtls' subdomain (e.g., mtls.identity.example.com)
    options.MutualTls.DomainName = "mtls";
    
    // Reference the certificate authentication scheme
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "mtls.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" },
            ClientSecrets =
            {
                // Authenticate using X.509 certificate thumbprint
                new Secret("ABC123DEF456", "mtls.thumbprint")
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateThumbprint
                }
            }
        }
    });

// Add mTLS secret validators
idsvrBuilder.AddMutualTlsSecretValidators();

// Add certificate authentication scheme
builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
        options.ValidateCertificateUse = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## How mTLS Works

When mTLS is enabled:

1. **Separate endpoints**: IdentityServer exposes mTLS-specific endpoints on the subdomain (`mtls.identity.example.com`). The discovery document includes these as `mtls_endpoint_aliases`.

2. **Certificate authentication**: Clients present their X.509 certificate during the TLS handshake. The `AddCertificate` authentication handler extracts and validates the certificate.

3. **Thumbprint matching**: `AddMutualTlsSecretValidators()` registers validators that match the presented certificate's thumbprint against the client's configured `X509CertificateThumbprint` secret.

4. **Token binding**: When a client authenticates via mTLS, the access token's `cnf` claim contains the certificate's SHA-256 thumbprint (`x5t#S256`), binding the token to that certificate.

## Secret Types for Certificate Authentication

| Secret Type | Matching Strategy |
|---|---|
| `SecretTypes.X509CertificateThumbprint` | Matches by SHA-1 thumbprint of the certificate |
| `SecretTypes.X509CertificateName` | Matches by Distinguished Name (DN) |

## Infrastructure Requirements

For mTLS to work, your reverse proxy / load balancer must:
- Terminate TLS with client certificate support, OR
- Forward client certificates to IdentityServer

In Kestrel, you can enable client certificates directly:

```csharp
builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.ConfigureHttpsDefaults(https =>
    {
        https.ClientCertificateMode = ClientCertificateMode.AllowCertificate;
    });
});
```
