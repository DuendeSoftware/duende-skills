# Adding SAML 2.0 Support to Duende IdentityServer

To add SAML support to Duende IdentityServer, you'll need to install the SAML component package and configure a service provider.

## Install the SAML Package

First, add the SAML NuGet package:

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

## Configure SAML in Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml2p();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Register the Service Provider

You'll need to configure the CRM as a SAML service provider. Create a configuration class:

```csharp
public static class SamlConfig
{
    public static IEnumerable<ServiceProvider> ServiceProviders =>
    new[]
    {
        new ServiceProvider
        {
            EntityId = "https://crm.contoso.com",
            AssertionConsumerServices = new[]
            {
                new AssertionConsumerService
                {
                    Location = "https://crm.contoso.com/saml/acs",
                    Binding = Saml2BindingType.Post
                }
            },
            SigningCertificates = new[] { /* SP signing cert */ }
        }
    };
}
```

Then register it:

```csharp
.AddInMemoryServiceProviders(SamlConfig.ServiceProviders);
```

## Key Points

- The SAML plugin adds endpoints for metadata, SSO, and SLO
- Configure the SP's signing certificate for request validation
- The metadata endpoint will be available at `/saml/metadata`
