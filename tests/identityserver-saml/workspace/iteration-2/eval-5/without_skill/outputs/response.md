# SAML Encrypted Assertions

To encrypt SAML assertions, you need to configure the service provider with their encryption certificate.

```csharp
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    EncryptAssertions = true,
    AssertionConsumerServiceUrls = new[] { new Uri("https://sp.example.com/saml/acs") }
};
```

You'll need to load the SP's encryption certificate and configure it. The exact configuration depends on your SAML library.

For IdP-initiated SSO, you would typically create an endpoint that generates a SAML response without a prior AuthnRequest. This is less secure than SP-initiated SSO but sometimes required by legacy SPs.

Check your IdentityServer/SAML library documentation for the specific settings to enable these features.
