# SAML Support in Duende IdentityServer: Package, License, and .NET Version

Short answers:

## Do I need a separate NuGet package?

**No.** SAML 2.0 Identity Provider support is **built directly into `Duende.IdentityServer`**. There is no separate SAML NuGet package to install. Once you reference `Duende.IdentityServer`, you enable SAML simply by calling `.AddSaml()` on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## What license edition is required?

SAML is a licensed feature. `.AddSaml()` requires one of:

- **Standard Edition** with the SAML **add-on**, **or**
- **Advanced Edition**, **or**
- **Custom Edition**

(The base/Starter tier does not include SAML.)

## Which version introduced it?

Built-in SAML support was **introduced in Duende IdentityServer v8.0**. You'll need to be on v8.0 or later.

## What about the .NET version?

The .NET requirement follows whatever the Duende.IdentityServer v8.x package you're using targets — it is not a SAML-specific requirement. Reference a supported .NET runtime for your IdentityServer 8.x version (a current LTS such as .NET 8, or newer as your project targets). Your build's `TargetFramework` just needs to be a framework that the IdentityServer 8.x package supports; SAML doesn't impose an additional .NET version beyond that.

## Summary

| Question | Answer |
|----------|--------|
| Separate NuGet package? | No — built into `Duende.IdentityServer` |
| License edition? | Standard (add-on), Advanced, or Custom |
| Introduced in? | Version 8.0 |
| .NET version? | Whatever your IdentityServer 8.x package supports (not SAML-specific) |
