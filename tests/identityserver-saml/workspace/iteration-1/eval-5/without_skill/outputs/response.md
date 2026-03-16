# SAML Encrypted Assertions and IdP-Initiated SSO

To configure encrypted assertions and IdP-initiated SSO in your SAML Identity Provider setup:

## Service Provider Configuration

```csharp
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "SP with Encrypted Assertions",

    AssertionConsumerServiceUrls = new[]
    {
        new Uri("https://sp.example.com/saml/acs")
    },

    // Enable assertion encryption
    EncryptAssertions = true,
    EncryptionCertificates = new[]
    {
        new X509Certificate2("certs/sp-encryption.cer")
    },

    // Allow IdP-initiated SSO
    AllowIdpInitiated = true,
};
```

## Program.cs Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(new[] { sp });
```

## Key Points

- Set `EncryptAssertions = true` to encrypt SAML assertions sent to this SP
- Provide the SP's encryption certificate from `certs/sp-encryption.cer`
- Set `AllowIdpInitiated = true` to enable IdP-initiated single sign-on
- The SP needs to have the corresponding private key to decrypt assertions
- Consider the security implications of IdP-initiated SSO as it's more susceptible to certain attacks
