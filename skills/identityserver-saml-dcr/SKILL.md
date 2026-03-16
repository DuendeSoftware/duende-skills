---
name: identityserver-saml-dcr
description: "Configuring Duende IdentityServer SAML 2.0 Identity Provider and Dynamic Client Registration (DCR): SAML service provider setup, attribute mapping, endpoints, extensibility, DCR authorization, software statements, and client configuration stores."
invocable: false
---

# SAML 2.0 Identity Provider and Dynamic Client Registration

## When to Use This Skill

- Setting up IdentityServer as a SAML 2.0 Identity Provider (IdP)
- Configuring SAML service providers with `SamlServiceProvider` model
- Understanding SAML metadata, endpoints, and bindings
- Customizing SAML attribute mapping with `ISamlClaimsMapper`
- Configuring `SamlOptions` (signing behavior, clock skew, name ID formats)
- Setting up Dynamic Client Registration (DCR) at `/connect/dcr`
- Customizing DCR validation with `IDynamicClientRegistrationValidator`
- Implementing software statement validation
- Securing the DCR endpoint with authorization policies
- Persisting dynamically registered clients with `IClientConfigurationStore`

## Part 1: SAML 2.0 Identity Provider

### Overview

IdentityServer can act as a SAML 2.0 Identity Provider, allowing SAML Service Providers (SPs) to authenticate users through IdentityServer. This feature requires the **Enterprise Edition** license and was introduced in version 8.0.

### Setup

```bash
dotnet add package Duende.IdentityServer.Saml
```

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

| Endpoint          | Path                  | Purpose                                           |
| ----------------- | --------------------- | ------------------------------------------------- |
| Metadata          | `/saml/metadata`      | SAML 2.0 IdP metadata document                    |
| Sign-in           | `/saml/sso`           | Receives `AuthnRequest` from SPs                  |
| Sign-in Callback  | `/saml/sso/callback`  | Internal callback after user authentication       |
| IdP-Initiated SSO | `/saml/idp-initiated` | Starts authentication without SP request (opt-in) |
| Logout            | `/saml/slo`           | Receives `LogoutRequest` from SPs                 |
| Logout Callback   | `/saml/slo/callback`  | Internal callback after logout processing         |

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
        new SamlAssertionConsumerServiceUrl
        {
            Url = "https://sp.example.com/saml/acs",
            IsDefault = true,
            Index = 0
        }
    ],
    AssertionConsumerServiceBinding = SamlBinding.HttpPost, // or HttpRedirect

    // Single Logout
    SingleLogoutServiceUrl = new SamlEndpointType
    {
        Location = "https://sp.example.com/saml/slo",
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
    DefaultNameIdFormat = SamlNameIdFormat.Persistent,
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

### SamlOptions

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(options =>
    {
        // Signing behavior for SAML responses
        // SignAssertion is recommended (signs only the assertion)
        options.DefaultSigningBehavior = SamlSigningBehavior.SignAssertion;

        // Require signed AuthnRequests from SPs
        options.WantAuthnRequestsSigned = false; // default

        // Clock skew tolerance
        options.DefaultClockSkew = TimeSpan.FromMinutes(5); // default

        // Maximum age of authentication requests
        options.DefaultRequestMaxAge = TimeSpan.FromMinutes(10);

        // Attribute name format in SAML assertions
        options.DefaultAttributeNameFormat = SamlAttributeNameFormat.Uri;

        // Supported Name ID formats (advertised in metadata)
        options.SupportedNameIdFormats =
        [
            SamlNameIdFormat.Persistent,
            SamlNameIdFormat.Transient,
            SamlNameIdFormat.EmailAddress
        ];

        // Metadata validity duration
        options.MetadataValidityDuration = TimeSpan.FromDays(7); // default

        // Default claim mappings (OIDC claim → WS claim type)
        options.DefaultClaimMappings = new Dictionary<string, string>
        {
            ["name"] = ClaimTypes.Name,
            ["email"] = ClaimTypes.Email,
            ["role"] = ClaimTypes.Role
        };
    });
```

### Signing Behavior

| Behavior                   | Signs                | Recommended                   |
| -------------------------- | -------------------- | ----------------------------- |
| `SignAssertion`            | Assertion only       | Yes (most interoperable)      |
| `SignResponse`             | Entire SAML response | Some SPs require this         |
| `SignAssertionAndResponse` | Both                 | Maximum security, less common |

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
                new SamlAssertionConsumerServiceUrl
                {
                    Url = "https://sp.example.com/saml/acs",
                    IsDefault = true,
                    Index = 0
                }
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

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(string entityId)
    {
        return await _db.SamlServiceProviders
            .FirstOrDefaultAsync(sp => sp.EntityId == entityId);
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
| `ISamlFrontChannelLogout`                 | Data interface for front-channel logout         |

## Part 2: Dynamic Client Registration (DCR)

### Overview

Dynamic Client Registration allows clients to register themselves at the `/connect/dcr` endpoint per RFC 7591. This feature requires the **Business Edition** or higher and has been available since version 6.3.

DCR uses a separate NuGet package and can be hosted in the same application as IdentityServer or in a separate host.

### Setup

```bash
dotnet add package Duende.IdentityServer.Configuration
```

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);

builder.Services.AddIdentityServerConfiguration();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapDynamicClientRegistration();

app.Run();
```

### Securing the DCR Endpoint

Apply standard ASP.NET Core authorization policies to the DCR endpoint:

```csharp
// Using JWT bearer for the DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");
```

### DCR Request and Response

**Registration request:**

```
POST /connect/dcr HTTP/1.1
Content-Type: application/json
Authorization: Bearer <access_token>

{
    "client_name": "My Dynamic App",
    "redirect_uris": ["https://app.example.com/callback"],
    "grant_types": ["authorization_code"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "client_secret_basic"
}
```

**Registration response:**

```json
{
  "client_id": "generated-client-id",
  "client_secret": "generated-secret",
  "client_name": "My Dynamic App",
  "redirect_uris": ["https://app.example.com/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "registration_client_uri": "https://identity.example.com/connect/dcr?client_id=generated-client-id",
  "registration_access_token": "..."
}
```

### Customizing DCR Validation

Extend `DynamicClientRegistrationValidator` to add custom validation logic:

```csharp
public class CustomDcrValidator : DynamicClientRegistrationValidator
{
    protected override Task ValidateGrantTypesAsync(
        DynamicClientRegistrationContext context)
    {
        // Only allow authorization_code
        var grantTypes = context.Request.GrantTypes;
        if (grantTypes.Any(gt => gt != "authorization_code"))
        {
            context.SetError("Grant type not allowed");
            return Task.CompletedTask;
        }

        return base.ValidateGrantTypesAsync(context);
    }

    protected override Task ValidateRedirectUrisAsync(
        DynamicClientRegistrationContext context)
    {
        // Enforce HTTPS redirect URIs
        var uris = context.Request.RedirectUris;
        if (uris.Any(u => !u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)))
        {
            context.SetError("Redirect URIs must use HTTPS");
            return Task.CompletedTask;
        }

        return base.ValidateRedirectUrisAsync(context);
    }

    protected override Task SetClientDefaultsAsync(
        DynamicClientRegistrationContext context)
    {
        // Set defaults for dynamically registered clients
        var client = context.Client;
        client.RequirePkce = true;
        client.AllowOfflineAccess = false;
        client.AccessTokenLifetime = 300; // 5 minutes

        return base.SetClientDefaultsAsync(context);
    }
}
```

Register:

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<CustomDcrValidator>();
```

### DynamicClientRegistrationContext

The context object passed to validation methods contains:

| Property  | Purpose                                               |
| --------- | ----------------------------------------------------- |
| `Client`  | The IdentityServer `Client` being built               |
| `Request` | The raw DCR request                                   |
| `Caller`  | The `ClaimsPrincipal` of the authenticated DCR caller |
| `Items`   | Dictionary for passing data between validation steps  |

### Software Statements

Software statements are signed JWTs that contain pre-approved client metadata. Validate them by overriding `ValidateSoftwareStatementAsync`:

```csharp
public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("Software statement required");
            return;
        }

        var handler = new JsonWebTokenHandler();
        var validationResult = await handler.ValidateTokenAsync(
            softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-authority.example.com",
                IssuerSigningKeys = await GetTrustedKeysAsync(),
                ValidateLifetime = true
            });

        if (!validationResult.IsValid)
        {
            context.SetError("Invalid software statement");
            return;
        }

        // Apply claims from software statement to the client
        var claims = validationResult.ClaimsIdentity;
        context.Client.ClientName = claims.FindFirst("software_name")?.Value;

        await base.ValidateSoftwareStatementAsync(context);
    }
}
```

### Other DCR Extensibility Points

| Interface                                     | Purpose                                  |
| --------------------------------------------- | ---------------------------------------- |
| `IDynamicClientRegistrationRequestProcessor`  | Process the DCR request (extend default) |
| `IDynamicClientRegistrationResponseGenerator` | Customize the DCR response               |

### Client Configuration Store

DCR needs a persistent store for dynamically registered clients. Use the Entity Framework implementation:

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

Or implement `IClientConfigurationStore` for a custom backing store:

```csharp
public class CustomClientConfigurationStore : IClientConfigurationStore
{
    public async Task AddAsync(Client client)
    {
        // Persist the dynamically registered client
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        // Retrieve a dynamically registered client
    }

    public async Task UpdateAsync(Client client)
    {
        // Update client configuration
    }

    public async Task DeleteAsync(string clientId)
    {
        // Remove a dynamically registered client
    }
}
```

### Separate DCR Host

DCR can be hosted in a separate application from IdentityServer:

```csharp
// Separate DCR host — Program.cs
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapDynamicClientRegistration().RequireAuthorization("dcr");

app.Run();
```

## Decision Matrix: SAML vs DCR

| Feature             | SAML 2.0 IdP                  | Dynamic Client Registration           |
| ------------------- | ----------------------------- | ------------------------------------- |
| Edition required    | Enterprise                    | Business or higher                    |
| Available since     | 8.0 (prerelease)              | 6.3                                   |
| NuGet package       | `Duende.IdentityServer.Saml`  | `Duende.IdentityServer.Configuration` |
| Protocol            | SAML 2.0                      | RFC 7591 (OAuth 2.0 DCR)              |
| Use case            | Federate with legacy SAML SPs | Automate client onboarding            |
| Can host separately | No (part of IdentityServer)   | Yes (separate host supported)         |

## Common Anti-Patterns

- ❌ Enabling `AllowIdpInitiated` on all SAML service providers
- ✅ Only enable IdP-initiated SSO for SPs that explicitly require it — it is less secure than SP-initiated flows

- ❌ Using `SignResponse` as the default signing behavior without SP requirement
- ✅ Use `SignAssertion` (default) — it is the most interoperable option

- ❌ Exposing the DCR endpoint without authentication
- ✅ Always secure `/connect/dcr` with an authorization policy

- ❌ Allowing dynamically registered clients to use any grant type
- ✅ Restrict allowed grant types and enforce PKCE in the DCR validator

- ❌ Using in-memory stores for SAML SPs or DCR clients in production
- ✅ Use persistent stores (database) for production deployments

## Common Pitfalls

1. **SAML Enterprise Edition requirement**: `AddSaml()` requires an Enterprise Edition license. Without it, the SAML endpoints are not available and startup may fail or produce licensing warnings.

2. **DCR Business Edition requirement**: `AddIdentityServerConfiguration()` requires a Business Edition or higher license. Community Edition does not support DCR.

3. **SAML metadata caching**: The `/saml/metadata` endpoint returns metadata with a validity duration (default 7 days via `MetadataValidityDuration`). SPs often cache this. If you rotate signing certificates, SPs may not pick up the new certificate until their cached metadata expires.

4. **SAML clock skew**: A `DefaultClockSkew` of 5 minutes (default) is typical, but some SPs have poorly synchronized clocks. Increase this if you see "response is not yet valid" or "response has expired" errors.

5. **DCR client secrets**: Dynamically registered clients receive generated secrets. Ensure your `IClientConfigurationStore` stores these securely (hashed, not plaintext).

6. **Software statement trust**: Software statements must be validated against a trusted signing key. Do not accept software statements signed by unknown issuers.

7. **SAML assertion encryption**: If `EncryptAssertions = true` is set on a service provider but no encryption certificate is provided, assertion generation will fail. Always provide `EncryptionCertificates` when enabling encryption.

8. **DCR separate host connectivity**: When hosting DCR separately, it must be able to communicate with IdentityServer's data stores. Ensure the `IClientConfigurationStore` is backed by the same database that IdentityServer reads from (or uses a shared data layer).

9. **ISamlClaimsMapper replaces defaults**: Implementing `ISamlClaimsMapper` completely replaces the default claim mapping. You must handle all claims in your implementation — the default mappings configured in `SamlOptions.DefaultClaimMappings` are not applied.
