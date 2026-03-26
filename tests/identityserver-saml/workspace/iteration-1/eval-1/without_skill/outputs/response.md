# Adding SAML 2.0 Support to IdentityServer

To add SAML support to your IdentityServer setup, you'll need to install the SAML component package and configure a service provider.

## Step 1: Install the SAML NuGet Package

First, add the SAML package to your project:

```bash
dotnet add package Duende.IdentityServer.Saml2p
```

## Step 2: Configure SAML in Program.cs

Update your `Program.cs` to add SAML support:

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

## Step 3: Register the Service Provider

You'll need to configure the Contoso CRM as a SAML service provider. The exact registration depends on the SAML library you use, but typically you'd define the SP configuration like this:

```csharp
var serviceProviders = new List<ServiceProvider>
{
    new ServiceProvider
    {
        EntityId = "https://crm.contoso.com",
        AssertionConsumerServiceUrl = "https://crm.contoso.com/saml/acs",
        SignOnBinding = Saml2BindingType.HttpPost
    }
};
```

Register these in your DI configuration and ensure IdentityServer knows about them.

## SAML Metadata

Your IdentityServer should expose a SAML metadata endpoint (typically at `/saml2/metadata`) that the CRM system can use to configure trust.