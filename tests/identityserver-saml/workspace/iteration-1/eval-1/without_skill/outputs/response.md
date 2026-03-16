# Adding SAML 2.0 Support to IdentityServer

To add SAML 2.0 Identity Provider support to your Duende IdentityServer, you'll need to install the SAML package and configure a service provider.

## Step 1: Install the SAML NuGet Package

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

## Step 2: Update Program.cs

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
    .AddSamlPlugin()
    .AddInMemoryServiceProviders(new List<ServiceProvider>
    {
        new ServiceProvider
        {
            EntityId = "https://crm.contoso.com",
            AssertionConsumerServices = new[]
            {
                new AssertionConsumerService
                {
                    Location = "https://crm.contoso.com/saml/acs",
                    Binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                }
            },
            SigningCertificates = new List<X509Certificate2>()
        }
    });

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseSamlPlugin();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Key Points

- You need the `Duende.IdentityServer.Saml2p` NuGet package for SAML support
- Call `.AddSamlPlugin()` on the IdentityServer builder
- Register your service providers with their entity ID and assertion consumer service URLs
- Add `app.UseSamlPlugin()` middleware
- The `EntityId` identifies the service provider (`https://crm.contoso.com`)
- The assertion consumer service URL is where SAML responses will be posted

This will expose a SAML metadata endpoint and handle SAML authentication requests from the CRM system.
