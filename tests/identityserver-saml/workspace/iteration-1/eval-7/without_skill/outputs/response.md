# SAML Support in Duende IdentityServer

## NuGet Package

To add SAML support to Duende IdentityServer, you'll need to install the SAML plugin package:

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

This is a separate package from the core IdentityServer package.

## License Requirements

SAML support in Duende IdentityServer typically requires a higher-tier license. You'll need at least the **Business Edition** to use SAML features. Check the Duende pricing page for the latest edition requirements.

## Setup

Once installed:

```csharp
builder.Services.AddIdentityServer()
    .AddSamlPlugin()
    .AddInMemoryServiceProviders(serviceProviders);
```

The SAML plugin integrates with your existing IdentityServer setup and shares the same user authentication pipeline.
