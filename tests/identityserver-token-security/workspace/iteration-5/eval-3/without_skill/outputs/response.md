# Setting up mTLS client authentication in IdentityServer

Mutual TLS lets a client authenticate at the token endpoint by presenting an X.509 client certificate instead of (or in addition to) a shared secret. Here's how to wire it up for `mtls.client` using its certificate thumbprint, with the mTLS endpoints served on an `mtls` sub-domain.

## Enable mTLS on the server

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
    options.MutualTls.DomainName = "mtls"; // endpoints exposed at mtls.<host>
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddMutualTlsSecretValidators();

// Certificate authentication so the presented client cert is available
builder.Services.AddAuthentication()
    .AddCertificate(options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.All;
        options.ValidateCertificateUse = true;
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

- `MutualTls.Enabled = true` turns the feature on.
- `MutualTls.DomainName = "mtls"` puts the mTLS-protected endpoints on the `mtls` sub-domain, e.g. `https://mtls.yourhost.com/connect/token`.
- `AddMutualTlsSecretValidators()` registers the validators that check certificate-based client secrets.
- `AddCertificate()` enables ASP.NET Core certificate authentication so the client certificate from the TLS handshake can be inspected.

## Configure the client with a certificate thumbprint secret

```csharp
new Client
{
    ClientId = "mtls.client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },
    ClientSecrets =
    {
        new Secret("ABC123DEF456")
        {
            Type = SecretTypes.X509CertificateThumbprint
        }
    }
}
```

The `Type = SecretTypes.X509CertificateThumbprint` tells IdentityServer to match the thumbprint of the certificate presented over the TLS channel against the secret value `ABC123DEF456`.

## Client side

When the client requests a token it must connect to the mTLS token endpoint (on the `mtls` sub-domain) and present its client certificate on the TLS connection. The mTLS endpoints are advertised in the discovery document, so read the token endpoint from there rather than assuming the default path.

## Hosting note

Your web server / Kestrel must be configured to request (but not necessarily require) client certificates so that the certificate reaches IdentityServer during the TLS handshake.
