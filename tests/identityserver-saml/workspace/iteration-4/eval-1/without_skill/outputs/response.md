# Adding SAML 2.0 IdP Support to Duende IdentityServer

Your current setup uses `Duende.IdentityServer` 8.0 on .NET 10 with OIDC clients. To add SAML 2.0 Identity Provider capability, you need the `Duende.IdentityServer.Saml` add-on package (a separately licensed component).

## 1. Add the NuGet Package

Update `IdentityServer.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
    <PackageReference Include="Duende.IdentityServer.Saml" Version="8.0.0" />
  </ItemGroup>
</Project>
```

> **Note:** The SAML component version should match your core IdentityServer version. Check NuGet for the exact version compatible with `Duende.IdentityServer` 8.0.

## 2. Configure SAML in Program.cs

Update your `Program.cs` to chain `.AddSamlPlugin()` after the standard IdentityServer setup, then register your service provider:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml.Models;
using Duende.IdentityServer.Saml.Stores;

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
        // Optional: configure the SAML IdP options
        // e.g. options.WantAuthenticationRequestsSigned = false;
    })
    .AddInMemorySamlServiceProviders(Config.ServiceProviders);

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
// SAML plugin middleware must be added after UseIdentityServer
app.UseSamlPlugin();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## 3. Register the CRM Service Provider

Add a `ServiceProviders` collection to your `Config` class:

```csharp
public static IEnumerable<ServiceProvider> ServiceProviders =>
[
    new ServiceProvider
    {
        EntityId = "https://crm.contoso.com",
        AssertionConsumerServices =
        {
            new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/acs")
        }
    }
];
```

Key properties on `ServiceProvider`:
- **`EntityId`** — the unique identifier for the SP (must match what the SP sends in its AuthnRequest).
- **`AssertionConsumerServices`** — where IdentityServer posts the SAML assertion. `HttpPost` binding sends a form POST to the ACS URL.

## 4. Expose the IdP Metadata

Once running, your IdP metadata will be available at:

```
https://<your-host>/saml/metadata
```

Provide this URL to the CRM team so they can configure their SP to trust your IdP.

## 5. Claims / Attribute Mapping

By default, IdentityServer maps the standard claims from your user's identity. If the CRM SP needs specific SAML attribute URIs, you can configure a `ClaimMapping` on the service provider:

```csharp
new ServiceProvider
{
    EntityId = "https://crm.contoso.com",
    AssertionConsumerServices =
    {
        new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/acs")
    },
    ClaimMapping =
    {
        { "sub",   "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified" },
        { "email", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" },
        { "name",  "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name" }
    }
}
```

## Summary of Changes

| File | Change |
|------|--------|
| `IdentityServer.csproj` | Added `Duende.IdentityServer.Saml` package reference |
| `Program.cs` | Chained `.AddSamlPlugin()` + `.AddInMemorySamlServiceProviders()`, added `app.UseSamlPlugin()` |
| `Config.cs` | Added `ServiceProviders` with the CRM SP registration |

> **License note:** The SAML component requires an Enterprise or Business Edition license from Duende Software. Verify your license tier before deploying.
