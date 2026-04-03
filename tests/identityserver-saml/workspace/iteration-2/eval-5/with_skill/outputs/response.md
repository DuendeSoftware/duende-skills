# SAML Encrypted Assertions with IdP-Initiated SSO

## Service Provider Configuration

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Saml.Models;

var spEncryptionCert = new X509Certificate2("certs/sp-encryption.cer");

var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Encrypted SP",

    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],

    // Enable assertion encryption
    EncryptAssertions = true,
    EncryptionCertificates =
    [
        spEncryptionCert
    ],

    // Enable IdP-initiated SSO for this SP
    AllowIdpInitiated = true
};
```

## Enable the IdP-Initiated SSO Endpoint

The IdP-initiated SSO endpoint is **disabled by default**. You must enable it explicitly:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Enable the IdP-initiated SSO endpoint
    options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders([sp]);
```

## Key Points

- **`EncryptAssertions = true`** — encrypts the SAML assertion using the SP's encryption certificate
- **`EncryptionCertificates`** — must be populated when `EncryptAssertions = true`, otherwise assertion generation will fail
- **`AllowIdpInitiated = true`** — allows this specific SP to receive IdP-initiated SSO flows
- **`options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true`** — enables the `/saml/idp-initiated` endpoint globally (disabled by default)
