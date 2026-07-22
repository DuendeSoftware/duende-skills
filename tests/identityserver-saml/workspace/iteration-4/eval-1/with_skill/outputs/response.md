# Adding SAML 2.0 Identity Provider Support to Duende IdentityServer

Your existing setup (`Program.cs`) is a standard IdentityServer with OIDC clients. Adding SAML IdP support is additive — you keep everything you have and chain `.AddSaml()` plus a service provider registration onto the existing builder.

---

## Prerequisites

**License**: SAML 2.0 IdP support requires the **Standard (add-on), Advanced, or Custom Edition** license. It will not work on the free Community edition.

**Package**: SAML is built into `Duende.IdentityServer` v8.0+ — no additional NuGet package is needed. Your `.csproj` already has the correct package:

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
```

---

## Step 1: Register SAML and the Service Provider

Update `Program.cs` to chain `.AddSaml()` and `.AddInMemorySamlServiceProviders(...)` onto the existing IdentityServer builder:

```csharp
// Program.cs — with SAML added
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Saml.Models; // SamlServiceProvider, IndexedEndpoint, etc.

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    // ── SAML additions ──────────────────────────────────────────
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

---

## Step 2: Define the Service Provider

Add a `SamlServiceProviders` collection to your `Config` class. For the CRM at `https://crm.contoso.com`:

```csharp
public static class Config
{
    // ... existing IdentityResources, ApiScopes, Clients ...

    public static IEnumerable<SamlServiceProvider> SamlServiceProviders =>
    [
        new SamlServiceProvider
        {
            // Required — uniquely identifies the SP
            EntityId = "https://crm.contoso.com",
            DisplayName = "Contoso CRM",

            // ACS endpoint — where the IdP posts the SAML assertion
            // Only HTTP-POST binding is supported for ACS
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

            // Claims this SP is allowed to receive
            // Must match identity resources defined above
            AllowedScopes = ["openid", "profile", "email"],

            // Map OIDC claim names → SAML attribute URIs
            ClaimMappings = new Dictionary<string, string>
            {
                ["sub"]   = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
                ["name"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
                ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
            },

            // NameID format — EmailAddress is the most common choice
            DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,

            // Signing — SignResponse is recommended for production
            SigningBehavior = SamlSigningBehavior.SignAssertion, // start here; upgrade to SignResponse later

            Enabled = true
        }
    ];
}
```

> **ACS binding gotcha**: `AssertionConsumerServiceUrls` only supports `SamlBinding.HttpPost`. If you configure `HttpRedirect` here the SP will fail validation and be treated as non-existent.

---

## Step 3: Verify the SAML Endpoints Are Live

Once the app starts, the following endpoints are available automatically:

| Purpose | URL |
|---------|-----|
| IdP Metadata | `https://your-idp.example.com/Saml2` |
| SSO (receive AuthnRequest) | `https://your-idp.example.com/Saml2/SSO` |
| SLO | `https://your-idp.example.com/Saml2/SLO` |

Point your CRM's SP configuration to the **metadata URL** (`/Saml2`) — it will auto-discover all endpoint URLs and signing certificates.

---

## Step 4: Update the Login Page for SAML Cancellation

The login Razor Page must call `DenyAuthenticationAsync` when the user clicks "Cancel". Without this, users who cancel a SAML login get stuck.

In your `Login.cshtml.cs`:

```csharp
// In the Cancel handler (or wherever the user abandons login):
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
if (context != null)
{
    // Works for both OIDC and SAML flows
    await _interaction.DenyAuthenticationAsync(context, new AuthorizationError
    {
        Error = OidcConstants.AuthorizeErrors.AccessDenied,
        ErrorDescription = "The user cancelled login."
    });
}
```

---

## Step 5: (Optional) Configure Global SAML Options

If you need to tune signing behavior, clock skew, or NameID claim source, configure `SamlOptions` via the `AddSaml(saml => { ... })` overload:

```csharp
.AddSaml(saml =>
{
    // Explicitly set the IdP EntityId (defaults to https://{host}/Saml2)
    // saml.EntityId = "https://idp.contoso.com/Saml2";

    // Require SPs to sign their AuthnRequests (default: true)
    saml.WantAuthnRequestsSigned = false; // relax for SPs that don't sign requests

    // Clock skew for assertion validation (default: 5 minutes)
    saml.DefaultClockSkew = TimeSpan.FromMinutes(5);

    // Assertion lifetime (default: 5 minutes)
    saml.DefaultAssertionLifetime = TimeSpan.FromMinutes(5);

    // Which claim type to use as the email-format NameID value
    saml.EmailNameIdClaimType = "email";

    // Metadata cache hints sent to SPs
    saml.Metadata.CacheDuration = TimeSpan.FromHours(12);
})
```

---

## The Complete Claim Pipeline

For your CRM SP, claims flow like this:

```
1. AllowedScopes = ["openid", "profile", "email"]
       ↓  (IdentityResources define which claim types belong to each scope)
2. Claims available: sub, name, given_name, family_name, email, email_verified, ...
       ↓  (optionally narrowed by RequestedClaimTypes)
3. ClaimMappings renames OIDC claim names to SAML attribute URIs
       ↓
4. SAML assertion contains <saml:Attribute> elements with the mapped URIs
```

If you omit `AllowedScopes`, the SP receives **no claims** — this is the most common configuration mistake.

---

## Summary of Changes to Your Files

| File | Change |
|------|--------|
| `Program.cs` | Chain `.AddSaml()` and `.AddInMemorySamlServiceProviders(Config.SamlServiceProviders)` |
| `Config` class | Add `SamlServiceProviders` property returning the CRM `SamlServiceProvider` |
| Login Razor Page | Add `DenyAuthenticationAsync` call on user cancel |

> **Next step for production**: Replace `AddInMemorySamlServiceProviders` with `.AddSamlServiceProviderStoreCache<YourStore>()` backed by EF Core or a custom `ISamlServiceProviderStore`. In-memory stores are development-only.
