# Setting Up mTLS Client Authentication in IdentityServer

Mutual TLS (mTLS) allows clients to authenticate using X.509 certificates instead of shared secrets. IdentityServer validates the client certificate at the TLS layer and can bind the certificate thumbprint to access tokens via the `cnf` claim.

## Updated Program.cs

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.Certificate;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable mTLS endpoints
    options.MutualTls.Enabled = true;

    // mTLS endpoints will be available on the 'mtls' subdomain
    // e.g., https://mtls.identity.example.com/connect/token
    options.MutualTls.DomainName = "mtls";

    // Reference the certificate authentication scheme
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Add mTLS secret validators to validate client certificates
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
                // Authenticate by X.509 certificate thumbprint
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

1. **mTLS Subdomain**: With `DomainName = "mtls"`, IdentityServer exposes mTLS-specific endpoints on `https://mtls.identity.example.com`. The standard endpoints remain available on the primary domain. Your reverse proxy must be configured to require client certificates only on the `mtls` subdomain.

2. **Certificate Authentication**: The `AddCertificate("Certificate", ...)` call registers ASP.NET Core's certificate authentication handler. This extracts and validates the client certificate from the TLS handshake. The `ClientCertificateAuthenticationScheme` tells IdentityServer which scheme to use.

3. **Secret Validation**: `AddMutualTlsSecretValidators()` registers validators that compare the TLS client certificate against client secrets. With `SecretTypes.X509CertificateThumbprint`, it matches the SHA-1 thumbprint of the presented certificate against the stored value.

4. **Client calls the mTLS token endpoint**: The client presents its certificate during the TLS handshake and sends a standard token request to `https://mtls.identity.example.com/connect/token`.

## Secret Types for mTLS

IdentityServer supports two approaches for certificate matching:

- **`SecretTypes.X509CertificateThumbprint`** — Matches the SHA-1 thumbprint of the certificate. Best for self-issued certificates.
- **`SecretTypes.X509CertificateName`** — Matches the distinguished name (DN) of the certificate. Best for PKI-issued certificates where you trust a CA.

```csharp
// PKI-based matching by distinguished name
new Secret(@"CN=client, OU=production, O=company", "client.dn")
{
    Type = IdentityServerConstants.SecretTypes.X509CertificateName
}
```

## Token Binding

When mTLS is used for client authentication, IdentityServer automatically embeds the certificate thumbprint in the access token via the `cnf` claim with `x5t#S256` (SHA-256 thumbprint), enabling APIs to verify the token was issued to the certificate holder.
