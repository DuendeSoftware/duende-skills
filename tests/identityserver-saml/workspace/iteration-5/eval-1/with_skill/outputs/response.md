# Adding SAML 2.0 IdP Support to Your Existing IdentityServer

Good news: SAML 2.0 Identity Provider support is **built into Duende.IdentityServer** (v8.0+). You do **not** need a separate NuGet package — your existing `Duende.IdentityServer` 8.0.0 reference already contains everything. You just need the appropriate license edition (**Standard add-on, Advanced, or Custom**).

To enable it you add `.AddSaml()` to your IdentityServer builder chain and register your service providers. Since you're still in dev, we'll use the in-memory SP store to get you going, then you can move to EF Core for production.

## Updated `Program.cs`

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml.Models; // SamlServiceProvider, IndexedEndpoint, SamlBinding

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    // --- SAML 2.0 IdP support ---
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
```

## Register the CRM Service Provider

Add a `SamlServiceProviders` collection to your `Config` class:

```csharp
public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
[
    new SamlServiceProvider
    {
        EntityId = "https://crm.contoso.com",
        DisplayName = "Contoso CRM",

        // ACS endpoints are HTTP-POST only and indexed
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

        // Identity resources the SP is allowed to receive claims from.
        // Without at least one AllowedScopes entry the SP gets NO claims
        // in the assertion (and it fails validation).
        AllowedScopes = ["openid", "profile", "email"]
    }
];
```

## What's happening here

- **`.AddSaml()`** wires up the SAML endpoints. By default they live under `/Saml2`:
  - `/Saml2` — IdP metadata
  - `/Saml2/SSO` — receives AuthnRequests
  - `/Saml2/SSO/Callback` — builds the SAML Response after login
  - `/Saml2/SLO` and `/Saml2/SLO/Callback` — Single Logout
- **`AssertionConsumerServiceUrls`** must use `IndexedEndpoint` with `Binding = SamlBinding.HttpPost`. HTTP-Redirect is **not** supported for ACS and will fail the automatic SP validation.
- **`AllowedScopes`** drives the claim pipeline: `AllowedScopes → RequestedClaimTypes → ClaimMappings`. An SP with an empty `AllowedScopes` is treated as invalid (returns null from the store).

## Next steps

- **Signing**: SAML signing requires an **X.509 certificate**. If you rely on Automatic Key Management with RSA keys, they are auto-wrapped into a self-signed X.509 container, so no extra work. But `AddDeveloperSigningCredential()` (raw RSA) **cannot** be auto-wrapped — register a real X.509 cert with a private key for SAML.
- **Login page**: update it to call `DenyAuthenticationAsync` so users who cancel during a SAML flow aren't left stuck.
- **Production**: replace `AddInMemorySamlServiceProviders` with the EF Core configuration store (`AddConfigurationStore`) or a custom `ISamlServiceProviderStore`.
- Grab the CRM's certificate and set `RequireSignedAuthnRequests` / `Certificates` if the SP signs its AuthnRequests.
