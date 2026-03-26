# Configuring Encrypted Assertions and IdP-Initiated SSO

Here's how to configure a SAML service provider with encrypted assertions and IdP-initiated SSO support.

## Service Provider Configuration

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Models;

public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
[
    new SamlServiceProvider
    {
        EntityId = "https://sp.example.com",
        DisplayName = "Example SP with Encryption",

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

        // Enable IdP-initiated SSO
        AllowIdpInitiated = true,

        // Other settings
        SigningBehavior = SamlSigningBehavior.SignAssertion
    }
];
```

## Enable the IdP-Initiated SSO Endpoint

The IdP-initiated SSO endpoint is **disabled by default**. You must explicitly enable it in `IdentityServerOptions.Endpoints`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Enable the IdP-initiated SSO endpoint
    options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Once enabled, the endpoint is available at `/saml/idp-initiated`. To start an IdP-initiated flow for the SP, navigate to:

```
https://your-idp.example.com/saml/idp-initiated?entityId=https://sp.example.com
```

## How Encryption Works

When `EncryptAssertions = true`:
1. IdentityServer encrypts the SAML assertion using the SP's encryption certificate
2. The SP decrypts the assertion using its private key
3. Only the SP with the matching private key can read the assertion contents

**Important:** Never set `EncryptAssertions = true` without providing `EncryptionCertificates`. Assertion generation will fail if no encryption certificate is available.

## Security Considerations

- **Assertion encryption** protects assertion contents in transit, complementing TLS
- **IdP-initiated SSO** is less secure than SP-initiated flows because there's no AuthnRequest to validate. Only enable it for SPs that explicitly require it
- The SP's encryption certificate should be the **public key only** (`.cer` file) — you don't need their private key