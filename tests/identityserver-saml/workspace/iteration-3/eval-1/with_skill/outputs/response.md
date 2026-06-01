# Adding SAML 2.0 IdP Support to Duende IdentityServer

SAML 2.0 IdP support is **built into Duende.IdentityServer** (v8.0+) — no separate NuGet package is needed. You just need an Advanced or Custom Edition license.

Here's how to add SAML support and register your CRM service provider:

## Updated Program.cs

```csharp
// Program.cs — IdentityServer with OIDC + SAML
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
                new IndexedEndpoint
                {
                    Location = "https://crm.contoso.com/saml/acs",
                    Binding = SamlBinding.HttpPost,
                    Index = 0,
                    IsDefault = true
                }
            ],
            AllowedScopes = ["openid", "profile", "email"],
            SigningBehavior = SamlSigningBehavior.SignAssertion
        }
    ];
}
```

## Key Points

1. **No additional NuGet package** — `.AddSaml()` is available directly from the `Duende.IdentityServer` package.
2. **`.AddSaml()`** enables the SAML endpoints (`/Saml2`, `/Saml2/SSO`, `/Saml2/SLO`).
3. **`AssertionConsumerServiceUrls`** must use `IndexedEndpoint` with `SamlBinding.HttpPost` (only HTTP-POST is supported for ACS).
4. **`AllowedScopes`** determines which claims are available to the SP — without it, no claims appear in the assertion.
5. Update your login page to call `DenyAuthenticationAsync` for SAML cancellation support.
