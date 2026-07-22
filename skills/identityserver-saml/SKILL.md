---
name: identityserver-saml
description: "Configuring Duende IdentityServer as a SAML 2.0 Identity Provider (IdP): service provider registration, SSO and SLO flows, claim mappings, extensibility interfaces, and production deployment patterns."
invocable: false
---

# SAML 2.0 Identity Provider

## When to Use This Skill

- Setting up IdentityServer as a SAML 2.0 Identity Provider (IdP)
- Registering SAML Service Providers with the `SamlServiceProvider` model
- Configuring SP-initiated SSO and Single Logout (SLO) flows
- Customizing claim-to-attribute mappings via `ClaimMappings` or extensibility interfaces
- Implementing production SP stores (EF Core, custom `ISamlServiceProviderStore`)
- Extending SAML behavior (custom NameID generation, signing, metadata, multi-tenant issuer)
- Linking an external SAML IdP as a federated authentication source (SP mode)

## Core Principles

- SAML 2.0 IdP support is **built into Duende.IdentityServer** (v8.0+) — no separate NuGet package
- Requires **Standard (add-on), Advanced, or Custom Edition** license
- SP-initiated SSO is the default; IdP-initiated SSO is opt-in per service provider
- `SignAssertion` is the default signing behavior; `SignResponse` is recommended for most deployments
- Use EF Core stores for service providers in production; in-memory is for development only
- Front-channel SLO uses iframes (not redirect chains); partial logout is expected behavior
- The claim pipeline flows: AllowedScopes → RequestedClaimTypes → ClaimMappings

Docs: https://docs.duendesoftware.com/identityserver/saml

## Setup

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Update the login page to call `DenyAuthenticationAsync` for SAML cancellation support (when user cancels login during a SAML flow).

## Endpoints

| Endpoint | Path | Purpose |
|----------|------|---------|
| Metadata | `/Saml2` | IdP metadata (certificates, endpoints, NameID formats) |
| Sign-in | `/Saml2/SSO` | Receives AuthnRequest (GET/POST) |
| Sign-in Callback | `/Saml2/SSO/Callback` | Builds SAML Response after authentication |
| Logout | `/Saml2/SLO` | Handles LogoutRequest/LogoutResponse |
| Logout Callback | `/Saml2/SLO/Callback` | Completes SLO round-trip |

Paths are customizable via `SamlOptions.Endpoints`.

### Profile Active Check

`IProfileService.IsActiveAsync` is called on every SSO request, including when the user already has an active session.
If `IsActive` returns `false`: passive requests (`IsPassive=true`) receive a SAML `NoPassive` error response; all other requests are redirected to the login page.
This is the recommended mechanism for blocking disabled or locked accounts without waiting for session expiry.

### Observability

All SAML endpoints emit audit events and OpenTelemetry telemetry counters.
SSO and SLO endpoints participate in distributed tracing via the `Duende.IdentityServer` activity source.
See docs for SAML audit events and `TelemetryMetricsCounters.SamlSso`.

## SamlServiceProvider Model

```csharp
new SamlServiceProvider
{
    // Required
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",

    // ACS endpoints (HTTP-POST only, indexed)
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://sp.example.com/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],

    // Single Logout (HTTP-Redirect only)
    SingleLogoutServiceUrls =
    [
        new SamlEndpointType
        {
            Location = "https://sp.example.com/saml/slo",
            Binding = SamlBinding.HttpRedirect
        }
    ],

    // Security
    SigningBehavior = SamlSigningBehavior.SignAssertion,
    RequireSignedAuthnRequests = true,
    Certificates =
    [
        new ServiceProviderCertificate
        {
            Certificate = spCert,
            Use = KeyUse.Signing
        }
    ],

    // Claims (identity resources the SP can access)
    AllowedScopes = ["openid", "profile", "email"],
    RequestedClaimTypes = ["email", "name"],  // optional narrowing
    ClaimMappings = new Dictionary<string, string>
    {
        ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
        ["name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
    },

    // NameID
    DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,

    // IdP-Initiated SSO (opt-in)
    AllowIdpInitiated = false,

    // Lifecycle / display
    Enabled = true,                   // false → reject all requests from this SP
    Description = "Optional notes",  // human-readable, not sent in SAML responses

    // Per-SP overrides (null = fall back to SamlOptions global default)
    AssertionLifetime = TimeSpan.FromMinutes(5),   // overrides SamlOptions.DefaultAssertionLifetime
    EmailNameIdClaimType = "email",                // overrides SamlOptions.EmailNameIdClaimType
    RequireSignedLogoutResponses = true,           // overrides SamlOptions.RequireSignedLogoutResponses
    AllowedSignatureAlgorithms = ["http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"],  // null → IdP default
    AuthnContextMappings = new Dictionary<string, string>  // overrides SamlOptions.DefaultAuthnContextMappings
    {
        ["pwd"] = "urn:oasis:names:tc:SAML:2.0:ac:classes:Password",
        ["mfa"] = "urn:oasis:names:tc:SAML:2.0:ac:classes:MobileTwoFactorContract"
    }
}
```

### Claim Pipeline

```
AllowedScopes (identity resources) → filters available claim types
    ↓
RequestedClaimTypes (optional narrowing) → selects specific claims
    ↓
ClaimMappings (OIDC claim name → SAML attribute URI) → output as <saml:Attribute>
```

Use `SamlOptions.DefaultClaimMappings` for global defaults; per-SP `ClaimMappings` override them.

## Configuration (SamlOptions)

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        saml.EntityId = "https://idp.example.com/Saml2"; // default: {host}/Saml2
        saml.EntityIdPath = "/Saml2";                    // path appended to host URL to form default EntityId
        saml.WantAuthnRequestsSigned = true;             // default: true
        saml.RequireSignedLogoutResponses = true;        // default: true
        saml.DefaultSigningBehavior = SamlSigningBehavior.SignAssertion;
        saml.DefaultClockSkew = TimeSpan.FromMinutes(5);
        saml.DefaultRequestMaxAge = TimeSpan.FromMinutes(5);
        saml.DefaultAssertionLifetime = TimeSpan.FromMinutes(5);
        saml.SupportedNameIdFormats = [SamlNameIdFormat.EmailAddress, SamlNameIdFormat.Unspecified];
        saml.MaxRelayStateLength = 80; // SAML spec requirement
        saml.MaxMessageSize = 1_048_576; // max chars of inbound SAML messages (default: 1 MB)

        // Session/state lifetimes
        saml.SigninStateLifetime = TimeSpan.FromMinutes(15);   // how long sign-in request state is retained
        saml.LogoutSessionLifetime = TimeSpan.FromMinutes(5);  // how long SLO session tracking state is retained

        // NameID claim type for email-format NameIDs (default: "email")
        saml.EmailNameIdClaimType = "email";

        // Global claim mappings
        saml.DefaultClaimMappings = new Dictionary<string, string>
        {
            ["name"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
            ["email"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
            ["role"] = "http://schemas.xmlsoap.org/ws/2005/05/identity/role"
        };

        // AuthnContext mappings (acr/amr → SAML AuthnContext URIs)
        saml.DefaultAuthnContextMappings = new Dictionary<string, string>
        {
            ["pwd"] = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"
        };

        // Optional error inspector callbacks for debugging interoperability issues
        // These can inspect or suppress parse errors on inbound SAML messages
        saml.AuthnRequestErrorInspector = (context, exception) => { /* inspect/suppress */ };
        saml.LogoutRequestErrorInspector = (context, exception) => { /* inspect/suppress */ };
        saml.LogoutResponseErrorInspector = (context, exception) => { /* inspect/suppress */ };
    });
```

### Metadata Options

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        saml.Metadata.CacheDuration = TimeSpan.FromHours(12);
        saml.Metadata.ExpiryDuration = TimeSpan.FromDays(5);
    });
```

### Endpoint Options

| Property | Default | Description |
|----------|---------|-------------|
| `SingleSignOnServicePath` | `"/Saml2/SSO"` | Path for the SSO endpoint |
| `SingleSignOnServiceBindings` | `[HttpRedirect, HttpPost]` | Bindings advertised in metadata (not which the endpoint accepts) |
| `SingleSignOnCallbackPath` | `"/Saml2/SSO/Callback"` | Internal callback path after user authenticates |
| `SingleLogoutServicePath` | `"/Saml2/SLO"` | Path for the SLO endpoint |
| `SingleLogoutServiceBindings` | `[HttpRedirect, HttpPost]` | Bindings advertised in metadata for SLO |
| `SingleLogoutCallbackPath` | `"/Saml2/SLO/Callback"` | Internal callback path for SLO completion |
| `StateIdParameterName` | `"samlStateId"` | Query string param name for the SAML sign-in state ID |

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        saml.Endpoints.SingleSignOnServicePath = "/Saml2/SSO";
        saml.Endpoints.SingleLogoutServicePath = "/Saml2/SLO";
    });
```

## Service Provider Stores

### In-Memory (Development)

```csharp
.AddInMemorySamlServiceProviders(new[]
{
    new SamlServiceProvider { EntityId = "...", /* ... */ }
});
```

### EF Core (Production — Recommended)

```csharp
.AddConfigurationStore(options =>
{
    options.ConfigureDbContext = b =>
        b.UseSqlServer(connectionString);
})
```

Run EF migrations: `dotnet ef migrations add Update_DuendeIdentityServer_v8_0`

### Custom Store

```csharp
.AddSamlServiceProviderStore<MySamlSpStore>()

public class MySamlSpStore : ISamlServiceProviderStore
{
    public Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken ct)
    { /* lookup from your backend */ }

    public IAsyncEnumerable<SamlServiceProvider> GetAllSamlServiceProvidersAsync(
        CancellationToken ct)
    { /* stream all SPs */ }
}
```

> **Note — Operational store auto-registration**: `AddOperationalStore()` automatically registers EF Core implementations of **both** `ISamlSigninStateStore` **and** `ISamlLogoutSessionStore`. When using the EF operational store, these do not need to be registered separately.

### Caching & Validation

```csharp
// Add HybridCache layer to any custom store
.AddSamlServiceProviderStoreCache<MySamlSpStore>()
```

Cache duration is controlled by `IdentityServerOptions.Caching.SamlServiceProviderStoreExpiration` (default: 15 minutes):

```csharp
builder.Services
    .AddIdentityServer(options =>
    {
        options.Caching.SamlServiceProviderStoreExpiration = TimeSpan.FromMinutes(30);
    })
    .AddSaml()
    .AddSamlServiceProviderStoreCache<MySamlServiceProviderStore>();
```

All stores are automatically wrapped with `ValidatingSamlServiceProviderStore<T>` that checks: EntityId required, ≥1 ACS URL (HTTP-POST only), ≥1 AllowedScopes, positive lifetimes. Invalid SPs are treated as non-existent.

## Single Logout (SLO)

SLO uses **front-channel logout via iframes** (not redirect chains):

1. SP sends LogoutRequest to `/Saml2/SLO`
2. IdentityServer ends local session
3. Renders iframes sending LogoutRequests to all other active SPs
4. Collects LogoutResponses from SPs
5. Sends final LogoutResponse to originating SP

**Key points:**
- Partial logout is normal (some SPs may not respond)
- User must stay on logout page for iframes to complete
- Use `ISamlLogoutSessionStore` for distributed deployments (tracks which SPs have active sessions)
- Short session lifetimes serve as SLO fallback

## IdP-Initiated SSO

> ⚠️ **CSRF Warning**: IdP-initiated SSO is inherently vulnerable to CSRF. There is no SAML-compliant way to implement it without CSRF exposure. Only enable it after careful security review.

**Recommended alternative**: Mimic OIDC third-party initiated login — create a dedicated SP endpoint that accepts a target application hint and redirects the user to the IdP with a standard SP-initiated AuthnRequest. This avoids the CSRF risk entirely.

**Enabling per SP**: If IdP-initiated SSO is genuinely required, set `AllowIdpInitiated = true` on the `SamlServiceProvider`.

**No built-in endpoint**: There is no built-in IdP-initiated SSO endpoint. Implement your own Razor Page or controller and inject `IIdpInitiatedSsoService`:

```csharp
// Key method on IIdpInitiatedSsoService:
Task<IdpInitiatedSsoResult> CreateResponseAsync(
    HttpContext httpContext, string spEntityId, string? relayState, CancellationToken ct);
```

Call `CreateResponseAsync` from your custom endpoint to generate and return the SAML Response to the SP. The SP must have `AllowIdpInitiated = true`; otherwise the call will fail.

## Extensibility

| Interface | Purpose |
|-----------|---------|
| `ISamlNameIdGenerator` | Custom NameID value derivation (e.g., from employee_id claim) |
| `ISamlSigningService` | HSM/Key Vault signing certificate integration |
| `ISaml2MetadataResponseGenerator` | Custom metadata extensions (org info, federation) |
| `ISaml2IssuerNameService` | Multi-tenant: dynamic entity ID per tenant |
| `ISaml2SsoInteractionResponseGenerator` | Custom step-up auth logic during SSO |
| `ISaml2SsoResponseGenerator` | Custom SAML Response generation |
| `ISamlLogoutNotificationService` | Selective SLO targeting; returns `SamlLogoutNotificationResult` (`Messages`: collection of `SamlLogoutRequestContext`, `SkippedCount`: int) |
| `ISaml2SloResponseGenerator` | Custom SLO `LogoutResponse` generation (success vs partial logout) |
| `ISamlLogoutSessionStore` | Distributed SLO state (Redis, EF Core); key method: `TryRecordResponseAsync(string requestId, string issuer, bool success, CancellationToken ct)`; `SamlLogoutSession` has `SkippedSpCount` (int), `ExpiresAtUtc` (DateTime), `ExpectedResponses` dictionary |
| `ISaml2FrontChannelLogoutRequestBuilder` | Custom logout request structure; `BuildLogoutRequestAsync` returns `SamlLogoutRequestContext` (wraps outbound message + `RequestId` + `SpEntityId` for response correlation) |
| `ISamlResourceResolver` | Dynamic scope filtering per SP |
| `IIdpInitiatedSsoService` | Portal "My Apps" dashboard for IdP-initiated flows |
| `IAuthnRequestValidator` | Custom SP access rules, IP/time-based controls |
| `ILogoutRequestValidator` | Custom SLO authorization rules |
| `ISamlSigninStateStore` | Distributed sign-in state (for multi-node deployments); methods include `UpdateSigninRequestStateAsync` |
| `ISamlServiceProviderConfigurationValidator` | Custom SP config validation rules |

### Example: Custom NameID Generator

```csharp
public class EmployeeNameIdGenerator : ISamlNameIdGenerator
{
    public Task<NameIdGenerationResult> GenerateAsync(
        NameIdGenerationContext context, CancellationToken ct)
    {
        var employeeId = context.Subject.FindFirst("employee_id")?.Value;
        if (employeeId is null)
            return Task.FromResult(NameIdGenerationResult.Failure(
                StatusCodes.Responder, StatusCodes.UnknownPrincipal,
                "Employee ID claim not found."));

        return Task.FromResult(NameIdGenerationResult.Success(
            new NameId(employeeId, context.ResolvedFormat)));
    }
}
```

### SAML Authentication Context in Login UI

Inject `IIdentityServerInteractionService` and call `GetAuthenticationContextAsync(returnUrl)`; pattern-match the result to `SamlAuthenticationContext` for customizing login flows per SP.

`SamlAuthenticationContext` properties:
- `ServiceProvider` — the SP that initiated the request
- `IdP` (string?) — IdP entity ID from `Scoping`, null if multiple IdPs listed
- `LoginHint` (string?) — login hint from NameID in AuthnRequest
- `Tenant` (string?) — tenant identifier from RequestedAuthnContext
- `PromptModes` — derived from `ForceAuthn` and `IsPassive` flags
- `RelayState` (string?) — relay state from the AuthnRequest
- `IsIdpInitiated` (bool) — whether this is an IdP-initiated SSO flow
- `RequestedAuthnContext` — authentication context requirements from the SP
- `StateId` (Guid) — identifier for sign-in state entry; needed when calling `DenyAuthenticationAsync`

## Using IdentityServer as a SAML Service Provider (SP Mode)

IdentityServer can consume SAML assertions from external IdPs via federation. Add a SAML authentication handler (e.g., `Sustainsys.Saml2` or `ITfoxtec.Identity.Saml2`) and configure it as an external provider in IdentityServer's login UI — same pattern as any external authentication scheme.

For step-by-step setup instructions, see the official docs: https://docs.duendesoftware.com/identityserver/ui/login/saml-provider/

> **Managing many SAML IdPs?** For scenarios with a large or changing set of external SAML identity providers, consider using **dynamic providers** instead of static registration. Dynamic providers allow you to manage IdP configurations at runtime without redeployment. See: https://docs.duendesoftware.com/identityserver/ui/login/dynamicproviders/#saml-providers

## Common Anti-Patterns

❌ Enabling `AllowIdpInitiated` on all SPs — only enable where explicitly required (less secure)
❌ Using `DoNotSign` outside of local testing
❌ Using in-memory SP stores in production
❌ Omitting `AllowedScopes` — SP gets no claims in the assertion
❌ Configuring ACS URLs with HTTP-Redirect binding (only HTTP-POST is supported)

## Common Pitfalls

1. **Edition requirement**: `AddSaml()` requires Standard (add-on), Advanced, or Custom Edition license.
2. **ACS binding**: Only HTTP-POST is supported for AssertionConsumerServiceUrls. HTTP-Redirect will fail validation.
3. **Clock skew**: Default 5 minutes. Increase if SPs report "response not yet valid" errors.
4. **Partial SLO**: Front-channel logout via iframes means some SPs may not respond. This is expected — don't treat it as an error.
5. **DenyAuthenticationAsync**: Login page must call this for SAML cancellation. Without it, users get stuck if they cancel.
6. **Operational stores**: For multi-node deployments, configure `ISamlSigninStateStore` and `ISamlLogoutSessionStore` (e.g., EF Core, Redis). Without them, SSO/SLO state is lost across nodes.
7. **Certificate rotation**: Metadata is cached (default 12h). SPs may not pick up new signing certs until cache expires.
8. **ClaimMappings vs AllowedScopes**: If `AllowedScopes` doesn't include a resource containing a claim type, that claim won't reach `ClaimMappings`.

## Related Skills

- `identityserver-configuration` — IdentityServer host configuration and options
- `identityserver-stores` — Persistent store patterns (EF Core, custom stores)
- `identity-security-hardening` — Key rotation, HTTPS enforcement
- `identityserver-ui-flows` — Login/logout UI flows that SAML integrates with
- `identityserver-upgrade-v7-to-v8` — Migration guide including SAML EF migrations
