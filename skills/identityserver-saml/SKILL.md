---
name: identityserver-saml
description: "Configuring Duende IdentityServer as a SAML 2.0 Identity Provider (IdP): service provider setup, endpoint configuration, attribute mapping, signing behavior, extensibility, and common pitfalls."
invocable: false
---

# SAML 2.0 Identity Provider

## When to Use This Skill

- Setting up IdentityServer as a SAML 2.0 Identity Provider (IdP)
- Configuring SAML service providers with `SamlServiceProvider` model
- Understanding SAML metadata, endpoints, and bindings
- Customizing SAML attribute mapping with `ISamlClaimsMapper`
- Configuring SAML options via `IdentityServerOptions.Saml` (signing behavior, clock skew, name ID formats)
- Implementing custom `ISamlServiceProviderStore` for production
- Enabling or disabling individual SAML endpoints

## Core Principles

- SAML 2.0 IdP support is **built into Duende.IdentityServer** (v8.0+) — no separate NuGet package required
- Requires **Enterprise Edition** license
- SP-initiated SSO is the default and recommended flow; IdP-initiated SSO is opt-in per service provider
- `SignAssertion` is the most interoperable default signing behavior
- Use persistent stores (database) for service providers in production

## Overview

IdentityServer can act as a SAML 2.0 Identity Provider, allowing SAML Service Providers (SPs) to authenticate users through IdentityServer. This feature requires the **Enterprise Edition** license and was introduced in version 8.0.

### Setup

SAML 2.0 is built into `Duende.IdentityServer` — no additional NuGet package is needed. Just call `.AddSaml()`:

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

### SAML Endpoints

IdentityServer exposes six SAML endpoints under the `/saml` prefix:

| Endpoint          | Path                      | Purpose                                           |
| ----------------- | ------------------------- | ------------------------------------------------- |
| Metadata          | `/saml/metadata`          | SAML 2.0 IdP metadata document                    |
| Sign-in           | `/saml/signin`            | Receives `AuthnRequest` from SPs                  |
| Sign-in Callback  | `/saml/signin_callback`   | Internal callback after user authentication       |
| IdP-Initiated SSO | `/saml/idp-initiated`     | Starts authentication without SP request (opt-in) |
| Logout            | `/saml/logout`            | Receives `LogoutRequest` from SPs                 |
| Logout Callback   | `/saml/logout_callback`   | Internal callback after logout processing         |

These paths can be customized via `IdentityServerOptions.Saml.UserInteraction` (a `SamlUserInteractionOptions` instance with `SignInPath`, `LogoutPath`, etc.).

#### Enabling/Disabling Endpoints

Individual SAML endpoints can be toggled via `IdentityServerOptions.Endpoints`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Endpoints.EnableSamlSignInEndpoint = true;            // default: true
    options.Endpoints.EnableSamlLogoutEndpoint = true;            // default: true
    options.Endpoints.EnableSamlMetadataEndpoint = true;          // default: true
    options.Endpoints.EnableSamlIdpInitiatedSsoEndpoint = false;  // default: false
});
```

### SamlServiceProvider Model

Each SAML Service Provider is registered with the following configuration:

```csharp
var sp = new SamlServiceProvider
{
    // Required
    EntityId = "https://sp.example.com",
    DisplayName = "Example Service Provider",

    // Assertion Consumer Service (where to send SAML responses)
    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],

    // Single Logout
    SingleLogoutServiceUrl = new SamlEndpointType
    {
        Location = new Uri("https://sp.example.com/saml/slo"),
        Binding = SamlBinding.HttpPost
    },

    // Security
    RequireSignedAuthnRequests = true,
    SigningCertificates =
    [
        new X509Certificate2("sp-signing.cer")
    ],
    EncryptAssertions = false,
    EncryptionCertificates = [], // required if EncryptAssertions = true

    // Claims and NameID
    DefaultNameIdFormat = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent",
    ClaimMappings = new Dictionary<string, string>
    {
        ["email"] = ClaimTypes.Email,
        ["name"] = ClaimTypes.Name
    },

    // Consent
    RequireConsent = false,

    // IdP-Initiated SSO
    AllowIdpInitiated = false, // opt-in only

    // Signing behavior (per-SP override)
    SigningBehavior = SamlSigningBehavior.SignAssertion
};
```

### Name ID Formats

| Format         | Value                                                    | Description                         |
| -------------- | -------------------------------------------------------- | ----------------------------------- |
| `Unspecified`  | `urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified`  | No specific format required         |
| `EmailAddress` | `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress` | Email-based identifier              |
| `Persistent`   | `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`   | Opaque persistent identifier        |
| `Transient`    | `urn:oasis:names:tc:SAML:2.0:nameid-format:transient`    | One-time-use identifier per session |

### SAML Options

SAML options are configured via the `IdentityServerOptions.Saml` property — not via an `AddSaml()` lambda:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Signing behavior for SAML responses
    // SignAssertion is recommended (signs only the assertion)
    options.Saml.DefaultSigningBehavior = SamlSigningBehavior.SignAssertion;

    // Require signed AuthnRequests from SPs
    options.Saml.WantAuthnRequestsSigned = false; // default

    // Clock skew tolerance
    options.Saml.DefaultClockSkew = TimeSpan.FromMinutes(5); // default

    // Maximum age of authentication requests
    options.Saml.DefaultRequestMaxAge = TimeSpan.FromMinutes(10);

    // Attribute name format in SAML assertions
    options.Saml.DefaultAttributeNameFormat = SamlAttributeNameFormat.Uri;

    // Metadata validity duration
    options.Saml.MetadataValidityDuration = TimeSpan.FromDays(7); // default

    // Default claim mappings (OIDC claim -> WS claim type)
    options.Saml.DefaultClaimMappings = new Dictionary<string, string>
    {
        ["name"] = ClaimTypes.Name,
        ["email"] = ClaimTypes.Email,
        ["role"] = ClaimTypes.Role
    };

    // Customize SAML endpoint paths (optional)
    options.Saml.UserInteraction.SignInPath = "/saml/signin";
    options.Saml.UserInteraction.LogoutPath = "/saml/logout";
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

### Signing Behavior

| Behavior        | Signs                          | Recommended                          |
| --------------- | ------------------------------ | ------------------------------------ |
| `SignAssertion`  | Assertion only                 | Yes (most interoperable)             |
| `SignResponse`   | Entire SAML response           | Some SPs require this                |
| `SignBoth`       | Both assertion and response    | Maximum security, less common        |
| `DoNotSign`      | Nothing                        | **Testing only** — never use in production |

### Service Provider Store

**In-memory (development/static):**

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(
    [
        new SamlServiceProvider
        {
            EntityId = "https://sp.example.com",
            DisplayName = "Example SP",
            AssertionConsumerServiceUrls =
            [
                new Uri("https://sp.example.com/saml/acs")
            ]
        }
    ]);
```

**Custom store (production):**

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddSamlServiceProviderStore<DatabaseServiceProviderStore>();

public class DatabaseServiceProviderStore : ISamlServiceProviderStore
{
    private readonly AppDbContext _db;

    public DatabaseServiceProviderStore(AppDbContext db) => _db = db;

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken cancellationToken)
    {
        return await _db.SamlServiceProviders
            .FirstOrDefaultAsync(
                sp => sp.EntityId == entityId,
                cancellationToken);
    }
}
```

### Extensibility

#### ISamlClaimsMapper

Completely replaces the default claim-to-attribute mapping:

```csharp
public class CustomSamlClaimsMapper : ISamlClaimsMapper
{
    public Task<IEnumerable<SamlAttribute>> MapClaimsAsync(
        IEnumerable<Claim> claims,
        SamlServiceProvider serviceProvider)
    {
        var attributes = new List<SamlAttribute>();

        foreach (var claim in claims)
        {
            // Custom mapping logic per SP
            if (serviceProvider.EntityId == "https://legacy-sp.example.com")
            {
                // Legacy SP expects different attribute names
                attributes.Add(new SamlAttribute
                {
                    Name = $"urn:custom:{claim.Type}",
                    Values = [claim.Value]
                });
            }
            else
            {
                attributes.Add(new SamlAttribute
                {
                    Name = claim.Type,
                    Values = [claim.Value]
                });
            }
        }

        return Task.FromResult<IEnumerable<SamlAttribute>>(attributes);
    }
}
```

Register:

```csharp
builder.Services.AddTransient<ISamlClaimsMapper, CustomSamlClaimsMapper>();
```

#### ISamlInteractionService

Use in the login UI to get SAML-specific authentication context:

```csharp
public class AccountController : Controller
{
    private readonly ISamlInteractionService _samlInteraction;

    public AccountController(ISamlInteractionService samlInteraction)
    {
        _samlInteraction = samlInteraction;
    }

    public async Task<IActionResult> Login(string returnUrl)
    {
        var context = await _samlInteraction.GetRequestContextAsync(returnUrl);
        if (context != null)
        {
            // This is a SAML AuthnRequest
            // context.ServiceProvider — the requesting SP
            // context.RequestedNameIdFormat — what Name ID format the SP wants
        }
        return View();
    }
}
```

#### Other Extensibility Points

| Interface                                 | Purpose                                         |
| ----------------------------------------- | ----------------------------------------------- |
| `ISamlSigninInteractionResponseGenerator` | Customize the interaction flow for SAML sign-in |
| `ISamlLogoutNotificationService`          | Custom logout notification handling             |

## When to Use SAML vs OIDC

| Consideration        | SAML 2.0 IdP                          | OpenID Connect                           |
| -------------------- | ------------------------------------- | ---------------------------------------- |
| Edition required     | Enterprise                            | All editions                             |
| Protocol             | SAML 2.0                              | OAuth 2.0 / OpenID Connect               |
| Use case             | Federate with legacy SAML SPs         | Modern web/mobile/API authentication      |
| NuGet package        | `Duende.IdentityServer` (built-in)    | `Duende.IdentityServer` (built-in)       |
| Can host separately  | No (part of IdentityServer)           | No (part of IdentityServer)              |

Prefer OpenID Connect for new integrations. Use SAML 2.0 only when required by an SP that does not support OIDC.

## Common Anti-Patterns

- **Enabling `AllowIdpInitiated` on all SAML service providers** — Only enable IdP-initiated SSO for SPs that explicitly require it. It is less secure than SP-initiated flows.

- **Using `SignResponse` as the default signing behavior without SP requirement** — Use `SignAssertion` (default). It is the most interoperable option.

- **Using in-memory stores for SAML SPs in production** — Use persistent stores (database) for production deployments.

## Common Pitfalls

1. **Enterprise Edition requirement**: `AddSaml()` requires an Enterprise Edition license. Without it, the SAML endpoints are not available and startup may fail or produce licensing warnings.

2. **Metadata caching**: The `/saml/metadata` endpoint returns metadata with a validity duration (default 7 days via `MetadataValidityDuration`). SPs often cache this. If you rotate signing certificates, SPs may not pick up the new certificate until their cached metadata expires.

3. **Clock skew**: A `DefaultClockSkew` of 5 minutes (default) is typical, but some SPs have poorly synchronized clocks. Increase this if you see "response is not yet valid" or "response has expired" errors.

4. **Assertion encryption**: If `EncryptAssertions = true` is set on a service provider but no encryption certificate is provided, assertion generation will fail. Always provide `EncryptionCertificates` when enabling encryption.

5. **ISamlClaimsMapper replaces defaults**: Implementing `ISamlClaimsMapper` completely replaces the default claim mapping. You must handle all claims in your implementation — the default mappings configured in `IdentityServerOptions.Saml.DefaultClaimMappings` are not applied.

## Related Skills

- `identityserver-configuration` — IdentityServer host configuration including `IdentityServerOptions`
- `identityserver-dcr` — Dynamic Client Registration (DCR) for automated client onboarding
- `identity-security-hardening` — Security hardening including key rotation and HTTPS enforcement
- `identityserver-stores` — Persistent store patterns (useful for custom `ISamlServiceProviderStore`)
- `identityserver-ui-flows` — Login/logout UI flows that SAML authentication integrates with
