# Adding SAML 2.0 Support to Duende IdentityServer

SAML 2.0 Identity Provider support is **built into Duende.IdentityServer** starting from v8.0 — you do **not** need to install a separate NuGet package. It does require an **Enterprise Edition** license.

## Step 1: Enable SAML and Register the Service Provider

Update your `Program.cs` to call `.AddSaml()` on the IdentityServer builder chain and register your service provider using `AddInMemorySamlServiceProviders`:

```csharp
// Program.cs — IdentityServer with OIDC + SAML 2.0
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
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();

// Configuration classes
public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "m2m.client",
            ClientName = "M2M Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "interactive",
            ClientName = "Interactive Client",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" }
        }
    ];

    public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
    [
        new SamlServiceProvider
        {
            EntityId = "https://crm.contoso.com",
            DisplayName = "Contoso CRM",
            AssertionConsumerServiceUrls =
            [
                new Uri("https://crm.contoso.com/saml/acs")
            ]
        }
    ];
}
```

## What This Does

1. **`.AddSaml()`** — Enables SAML 2.0 IdP functionality. This registers the SAML middleware, endpoints (`/saml/metadata`, `/saml/signin`, `/saml/logout`, etc.), and required services.

2. **`.AddInMemorySamlServiceProviders(...)`** — Registers your SAML service providers in memory. For production, you'd use a persistent store (database) instead.

3. **`SamlServiceProvider`** — The model representing a SAML SP:
   - `EntityId` is set to `https://crm.contoso.com` (the SP's unique identifier)
   - `AssertionConsumerServiceUrls` contains the URL where IdentityServer will POST the SAML assertion (`https://crm.contoso.com/saml/acs`)

## No Additional NuGet Package Needed

Your existing `IdentityServer.csproj` already references `Duende.IdentityServer` version 8.0.0, which includes SAML support. No changes to the project file are required.

## SAML Metadata

Once configured, your IdentityServer will expose a SAML metadata endpoint at `/saml/metadata`. Point the Contoso CRM SP at this URL so it can discover your IdP's signing certificates, supported bindings, and endpoints.