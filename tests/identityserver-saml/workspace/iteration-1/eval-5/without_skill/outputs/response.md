# Configuring Encrypted SAML Assertions and IdP-Initiated SSO

Here's how to set up a SAML service provider with encrypted assertions and IdP-initiated single sign-on.

## Service Provider Configuration

```csharp
using System.Security.Cryptography.X509Certificates;

var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",

    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],

    // Enable assertion encryption
    EncryptAssertions = true,
    EncryptionCertificates =
    [
        new X509Certificate2("certs/sp-encryption.cer")
    ],

    // Allow IdP-initiated SSO
    AllowIdpInitiated = true
};
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(new[] { sp });
```

## IdP-Initiated SSO

With `AllowIdpInitiated = true`, IdentityServer can start a login flow without the SP sending an AuthnRequest first. This is useful for portal-style applications where users click links in your IdP to access different SPs.

## Encryption Notes

- The `.cer` file contains the SP's public key for encryption
- The SP uses its private key to decrypt assertions
- Make sure the certificate is valid and not expired
- Test encryption thoroughly before going to production