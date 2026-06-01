# SAML Support in Duende IdentityServer

## NuGet Package

Duende IdentityServer has a separate SAML component. You'll need to add:

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

## License

SAML support requires a Business or Enterprise license from Duende Software. The free/community edition does not include SAML capabilities.

## .NET Version

Duende IdentityServer typically targets the latest LTS release of .NET. For the current version, you'll need .NET 8 or later.

## Getting Started

After installing the package, enable SAML in your startup:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml2p();
```

This adds the SAML 2.0 Identity Provider endpoints to your IdentityServer instance.
