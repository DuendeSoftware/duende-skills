# Adding SAML 2.0 Support to Duende IdentityServer

Great news — SAML 2.0 IdP support is **built into Duende.IdentityServer** (v8.0+), so you do **not** need a separate NuGet package. Your existing `Duende.IdentityServer` package reference is all you need. However, note that SAML requires the **Enterprise Edition** license.

Here's how to add SAML support and register your CRM service provider:

## Updated Program.cs

```csharp
// Program.cs — IdentityServer with OIDC + SAML support
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Models.Saml;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    // Add SAML 2.0 IdP support — no extra NuGet package needed
    .AddSaml()
    // Register SAML Service Providers (in-memory for dev/test)
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

    // SAML Service Providers
    public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
    [
        new SamlServiceProvider
        {
            EntityId = "https://crm.contoso.com",
            DisplayName = "Contoso CRM",
            AssertionConsumerServiceUrls =
            [
                new Uri("https://crm.contoso.com/saml/acs")
            ],
            RequireConsent = false,
            SigningBehavior = SamlSigningBehavior.SignAssertion
        }
    ];
}
```

## Key Points

1. **`.AddSaml()`** enables SAML 2.0 IdP functionality on the IdentityServer builder chain. No separate NuGet package is required — it's built into `Duende.IdentityServer`.

2. **`.AddInMemorySamlServiceProviders()`** registers the SAML service providers. For production, use a persistent store via `AddSamlServiceProviderStore<T>()`.

3. The `SamlServiceProvider` is configured with:
   - `EntityId = "https://crm.contoso.com"` — the SP's unique identifier
   - `AssertionConsumerServiceUrls` containing `https://crm.contoso.com/saml/acs` — where SAML responses are posted

4. IdentityServer will expose SAML endpoints at `/saml/metadata`, `/saml/signin`, `/saml/logout`, etc.

5. Your existing OIDC clients continue to work alongside the SAML service providers.

## No Changes to .csproj

Your existing project file already has `Duende.IdentityServer` v8.0.0 — no additional packages are needed:

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
```
