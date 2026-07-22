# Adding SAML Support to IdentityServer: Package, License, and .NET Requirements

## NuGet Package

Yes, SAML support in Duende IdentityServer requires a **separate NuGet package**. It is not included in the core `Duende.IdentityServer` package.

The package you need is:

```
Duende.IdentityServer.EntityFramework
```

Wait — for SAML specifically, the package is:

```
Duende.IdentityServer.Saml
```

Install it via the .NET CLI:

```bash
dotnet add package Duende.IdentityServer.Saml
```

Or via the NuGet Package Manager:

```
Install-Package Duende.IdentityServer.Saml
```

This package adds the SAML 2.0 identity provider plugin on top of Duende IdentityServer, enabling it to act as a SAML IdP and issue SAML assertions to service providers.

---

## License Edition Required

SAML support is **not available on all Duende IdentityServer license tiers**. It is a premium add-on feature.

Based on Duende's licensing structure:

- **Community Edition** — Free for qualifying organizations (revenue under threshold), but **SAML is not included**
- **Starter Edition** — Basic paid tier; SAML support may not be included
- **Business Edition** — SAML support is typically included at this tier
- **Enterprise Edition** — Full features including SAML

> **Important:** You must check the current Duende Software pricing page at [duendesoftware.com](https://duendesoftware.com) for the exact tier that includes SAML, as licensing tiers and inclusions can change. You will receive a `Licensee` and `LicenseKey` from Duende that must be supplied in your configuration:

```csharp
builder.Services.AddIdentityServer()
    // ...
    .AddSamlPlugin(options =>
    {
        options.Licensee = "YOUR_LICENSEE_NAME";
        options.LicenseKey = "YOUR_LICENSE_KEY";
    });
```

Without a valid license key that includes SAML, the plugin will either not function or run in a restricted/trial mode.

---

## .NET Version Requirements

Duende IdentityServer (and its SAML plugin) targets modern .NET versions. As of the time of writing:

| Duende IdentityServer Version | Supported .NET Versions |
|-------------------------------|------------------------|
| v6.x | .NET 6, .NET 7 |
| v7.x | .NET 7, .NET 8 |
| v8.x (latest) | .NET 8, .NET 9 |

**Minimum recommended:** **.NET 8** (LTS) for new projects.

> .NET Framework is **not supported**. Duende IdentityServer is built on ASP.NET Core and requires .NET (Core) 6 or later.

---

## Minimal Setup Example

Here's a minimal example of adding SAML to an existing IdentityServer setup:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    // Add SAML plugin
    .AddSamlPlugin(options =>
    {
        options.Licensee = "YourLicensee";
        options.LicenseKey = "YourLicenseKey";
    })
    // Register SAML service providers
    .AddInMemoryServiceProviders(Config.ServiceProviders);

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
// Add SAML endpoints middleware
app.UseSamlPlugin();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

---

## Summary

| Requirement | Answer |
|-------------|--------|
| Separate NuGet package? | **Yes** — `Duende.IdentityServer.Saml` |
| License required? | **Yes** — Business or Enterprise edition (verify at duendesoftware.com) |
| Minimum .NET version? | **.NET 6** minimum; **.NET 8** recommended (LTS) |
| .NET Framework supported? | **No** |
