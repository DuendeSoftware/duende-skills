# Setting up mTLS client authentication

To let `mtls.client` authenticate with its X.509 client certificate and expose the mTLS endpoints on the `mtls` sub-domain, you need three things: enable mTLS in the IdentityServer options, register the mTLS secret validators plus a certificate authentication scheme, and give the client an `X509CertificateThumbprint` secret.

## IdentityServer configuration (`Program.cs`)

```csharp
using Microsoft.AspNetCore.Authentication.Certificate;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Turn on mutual TLS support
    options.MutualTls.Enabled = true;

    // Publish the mTLS-protected endpoints on the "mtls" sub-domain,
    // e.g. https://mtls.host/connect/token
    options.MutualTls.DomainName = "mtls";

    // The authentication scheme used to surface the client certificate
    options.MutualTls.ClientCertificateAuthenticationScheme = "Certificate";
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Register the mTLS secret validators so certificate secrets can be checked
idsvrBuilder.AddMutualTlsSecretValidators();

// Certificate authentication scheme referenced above
builder.Services.AddAuthentication()
    .AddCertificate("Certificate", options =>
    {
        // Self-issued client cert matched by thumbprint
        options.AllowedCertificateTypes = CertificateTypes.SelfSigned;
        options.ValidateCertificateUse = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Client configuration

Because the certificate is matched by its thumbprint (self-issued), use `SecretTypes.X509CertificateThumbprint`:

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "mtls.client",
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },
    ClientSecrets =
    {
        new Duende.IdentityServer.Models.Secret("ABC123DEF456", "mtls.client thumbprint")
        {
            Type = Duende.IdentityServer.IdentityServerConstants.SecretTypes.X509CertificateThumbprint
        }
    }
}
```

The secret's `Value` is the certificate's SHA-1 thumbprint (`ABC123DEF456` in your case). IdentityServer matches the thumbprint of the certificate presented on the TLS channel against this secret.

> Use `SecretTypes.X509CertificateThumbprint` for **self-issued** certificates (matched by thumbprint) and `SecretTypes.X509CertificateName` for **PKI/chained** certificates (matched by distinguished name).

## How the mTLS sub-domain endpoints are discovered

With `DomainName = "mtls"`, the token/introspection/etc. endpoints for mTLS live at `https://mtls.host/connect/...`. These URLs are published in discovery under `mtls_endpoint_aliases`, so clients must read them from there rather than the standard endpoints:

```csharp
var tokenEndpoint = disco.MtlsEndpointAliases?.TokenEndpoint;
```

## Notes

- mTLS **client authentication** and **token binding** are available in **all editions** of IdentityServer.
- When requesting the token, the client must present the same certificate over the TLS channel and should use `ClientCredentialStyle.PostBody` — the default `AuthorizationHeader` style does not work in mTLS scenarios.
