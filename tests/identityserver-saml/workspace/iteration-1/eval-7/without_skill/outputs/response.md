# SAML Support in Duende IdentityServer

## NuGet Package

To add SAML support to Duende IdentityServer, you'll likely need an additional package. Duende has historically offered SAML as a separate component:

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

Check the Duende documentation for the exact package name as it may have changed across versions.

## License Requirements

SAML support in Duende IdentityServer requires a commercial license. Duende offers different editions:

- **Community** — Free for small companies
- **Business** — Standard commercial features
- **Enterprise** — Full feature set including advanced protocols

SAML is typically included in the Business or Enterprise editions. Check Duende's pricing page for the specific edition you need.

## Setup

Once you have the package installed and the proper license:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml2p()  // or AddSaml() depending on version
    .AddInMemorySamlServiceProviders(serviceProviders);
```

Refer to the Duende documentation for version-specific setup instructions.