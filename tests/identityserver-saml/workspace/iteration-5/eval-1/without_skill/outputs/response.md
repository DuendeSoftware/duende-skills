# Adding SAML 2.0 IdP Support to Duende IdentityServer

To turn IdentityServer into a SAML 2.0 Identity Provider you'll typically add a SAML module and register your service providers. Below is a common approach.

## 1. Add the SAML package

Duende/IdentityServer's SAML support historically ships as a separate add-on package. Add it to your project:

```xml
<PackageReference Include="Rsk.Saml" Version="6.*" />
<!-- (Rock Solid Knowledge's SAML2P plugin for Duende IdentityServer) -->
```

Then reference it in `Program.cs`.

## 2. Enable SAML on the IdentityServer builder

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSamlPlugin(options =>
    {
        options.Licensee = "YourCompany";
        options.LicenseKey = "your-license-key";
        options.WantAuthenticationRequestsSigned = true;
    })
    .AddInMemoryServiceProviders(Config.ServiceProviders);
```

## 3. Register the CRM service provider

```csharp
public static IEnumerable<ServiceProvider> ServiceProviders =>
[
    new ServiceProvider
    {
        EntityId = "https://crm.contoso.com",
        AssertionConsumerServices =
        {
            new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/acs")
        },
        SigningCertificates = { /* SP cert if it signs requests */ }
    }
];
```

## 4. Wire up middleware

```csharp
app.UseIdentityServer();
app.UseIdentityServerSamlPlugin();
```

## Notes

- SAML uses X.509 certificates for signing assertions and responses. Make sure your IdentityServer has a signing certificate configured.
- The service provider's Assertion Consumer Service (ACS) URL is where the IdP POSTs the SAML assertion — here `https://crm.contoso.com/saml/acs` using the HTTP-POST binding.
- Map the claims you want to send to the SP (e.g., email, name) into SAML attributes.
- Test against the SP's metadata to confirm EntityId and ACS URL match exactly.

Because SAML support in the Duende ecosystem is a licensed add-on, double-check the exact package name and configuration API against the current Duende documentation, as the API surface can differ between versions.
