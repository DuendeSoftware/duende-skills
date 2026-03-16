# Encrypted Assertions and IdP-Initiated SSO

Here's how to configure a SAML service provider in Duende IdentityServer with encrypted assertions and IdP-initiated SSO support.

## SamlServiceProvider Configuration

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Models.Saml;

var encryptedSp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "SP with Encrypted Assertions",

    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],

    // Enable assertion encryption
    EncryptAssertions = true,

    // Load the SP's encryption certificate
    EncryptionCertificates =
    [
        new X509Certificate2("certs/sp-encryption.cer")
    ],

    // Enable IdP-initiated SSO for this SP
    AllowIdpInitiated = true,

    SigningBehavior = SamlSigningBehavior.SignAssertion
};
```

## Enable the IdP-Initiated SSO Endpoint

The IdP-initiated SSO endpoint is **disabled by default**. You must explicitly enable it via `IdentityServerOptions.Endpoints`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Enable the IdP-initiated SSO endpoint
    options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(new[]
    {
        encryptedSp
    });
```

## Full Program.cs

```csharp
using System.Security.Cryptography.X509Certificates;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Models.Saml;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;

    // Enable IdP-initiated SSO endpoint (default: false)
    options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    .AddInMemorySamlServiceProviders(new[]
    {
        new SamlServiceProvider
        {
            EntityId = "https://sp.example.com",
            DisplayName = "Encrypted SP",
            AssertionConsumerServiceUrls =
            [
                new Uri("https://sp.example.com/saml/acs")
            ],
            EncryptAssertions = true,
            EncryptionCertificates =
            [
                new X509Certificate2("certs/sp-encryption.cer")
            ],
            AllowIdpInitiated = true
        }
    });

builder.Services.AddRazorPages();
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```

## Key Points

- **`EncryptAssertions = true`** enables encryption of the SAML assertion for this SP
- **`EncryptionCertificates`** must be populated when `EncryptAssertions = true` — otherwise assertion generation will fail
- **`AllowIdpInitiated = true`** enables IdP-initiated SSO for this specific SP (it's `false` by default)
- The global endpoint **`options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = true`** must also be set to make the `/saml/idp-initiated` endpoint available
- IdP-initiated SSO is less secure than SP-initiated; only enable when required
