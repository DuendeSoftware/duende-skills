# Setting Up Duende IdentityServer as a SAML 2.0 Identity Provider

SAML 2.0 IdP support is **built into Duende.IdentityServer** (v8.0+) — no separate NuGet package is required. Just call `.AddSaml()` on the IdentityServer builder.

## Updated Program.cs

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml.Models;

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

## Key Points

- **No separate NuGet package** — SAML is built into `Duende.IdentityServer` v8.0+
- **`.AddSaml()`** enables the SAML 2.0 IdP functionality
- **`AddInMemorySamlServiceProviders`** registers the service providers (for production, use a persistent store)
- The `SamlServiceProvider` has `EntityId` set to the SP's entity ID and `AssertionConsumerServiceUrls` containing the ACS URL
- SAML endpoints are automatically exposed at `/saml/metadata`, `/saml/signin`, etc.
