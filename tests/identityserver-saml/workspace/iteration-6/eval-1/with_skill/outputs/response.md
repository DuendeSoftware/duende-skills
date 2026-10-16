# Adding SAML 2.0 IdP support to your IdentityServer

SAML IdP support is built into `Duende.IdentityServer` v8 (you already have 8.0.0) — **no extra package**. It needs a Standard (add-on), Advanced or Custom edition license.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

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
```

```csharp
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
                Binding = SamlBinding.HttpPost,   // only HTTP-POST is supported for ACS
                Index = 0,
                IsDefault = true
            }
        ],
        // Without AllowedScopes the SP gets no claims, and validation requires >= 1
        AllowedScopes = ["openid", "profile", "email"],
        ClaimMappings = new Dictionary<string, string>
        {
            ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            ["name"]  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
        },
        DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,
        SigningBehavior = SamlSigningBehavior.SignAssertion,
        // If the SP signs AuthnRequests, add its public cert:
        // RequireSignedAuthnRequests = true,
        // Certificates = [ new ServiceProviderCertificate { Certificate = spCert, Use = KeyUse.Signing } ]
        RequireSignedAuthnRequests = false
    }
];
```

## Things to know

- **Endpoints** (give them to the SP, or point it at the metadata URL): metadata `/Saml2`, SSO `/Saml2/SSO`, SLO `/Saml2/SLO`.
- **ACS binding**: HTTP-POST only; HTTP-Redirect fails validation. A valid SP needs an EntityId, ≥1 ACS URL, ≥1 AllowedScopes.
- **Signing**: SAML needs an X.509 certificate with private key. Automatic key management (RSA) wraps keys into self-signed certs automatically; `AddDeveloperSigningCredential()` does not work for SAML.
- **Login page**: call `DenyAuthenticationAsync` when the user cancels during a SAML flow, otherwise they get stuck.
- **Production**: replace the in-memory SP store with the EF configuration store (`AddConfigurationStore`, run the v8 migration) or a custom `ISamlServiceProviderStore`. For multi-node, also configure the operational store for `ISamlSigninStateStore`/`ISamlLogoutSessionStore`.
- `SignAssertion` is the default; consider `SignResponse` too if the SP expects it.
