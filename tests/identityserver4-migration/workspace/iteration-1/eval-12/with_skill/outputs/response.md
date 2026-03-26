# Migrating the IdentityServer4 Quickstart UI to Duende IdentityServer

## Namespace Updates in Razor Views

Update all `@using` directives in your `.cshtml` files:

### _ViewImports.cshtml
```cshtml
@* Old *@
@using IdentityServer4

@* New *@
@using Duende.IdentityServer
```

Search all `.cshtml` files for `@using IdentityServer4` and replace with `@using Duende.IdentityServer`. This includes:
- `_ViewImports.cshtml` (affects all views)
- Individual view files that have their own `@using` directives
- Layout files

## Duende Templates Use Razor Pages, Not MVC Controllers

The Duende IdentityServer UI templates have **diverged significantly** from the IdentityServer4 Quickstart UI:

| IdentityServer4 Quickstart UI | Duende IdentityServer Templates |
|-------------------------------|--------------------------------|
| MVC Controllers (`AccountController`, `ConsentController`) | Razor Pages (`Pages/Account/Login.cshtml`, `Pages/Consent/Index.cshtml`) |
| Views under `Views/Account/`, `Views/Consent/` | Pages under `Pages/` |
| Controllers + ViewModels | PageModels with OnGet/OnPost |

## Recommended Approach: Scaffold Fresh Templates

The cleanest approach is to scaffold the current Duende UI templates and port your customizations:

```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

This creates the full set of Duende UI pages in your project. Diff the output against your existing UI to identify where your customizations should go.

## Existing MVC UI Will Still Work (With Limitations)

Your existing MVC-based UI (`AccountController`, `ConsentController`, etc.) **will still compile and work** after updating namespaces. However, it will miss newer UI flows that Duende templates include:

- **Device flow authorization page** — for input-constrained devices
- **CIBA (Client-Initiated Backchannel Authentication) page** — for decoupled auth flows
- **Dynamic identity provider management pages** — for runtime provider configuration
- **Server-side session management pages** — for viewing/revoking active sessions

## Fix v4 API Changes in Controllers

If you keep your MVC controllers (or if you're also migrating from v3 to v4), fix these API changes:

### AuthorizationRequest property access
```csharp
// Old (v3)
var clientId = request.ClientId;

// New (v4+)
var clientId = request.Client.ClientId;
```

### Consent scopes
```csharp
// Old (v3)
var grantedConsent = new ConsentResponse
{
    ScopesConsented = consentedScopes
};

// New (v4+)
var grantedConsent = new ConsentResponse
{
    ScopesValuesConsented = consentedScopes  // renamed property
};
```

### Grant management
```csharp
// Old (v3)
await _interaction.GetAllUserConsentsAsync();

// New (v4+)
await _interaction.GetAllUserGrantsAsync();
```

### Validated resources
```csharp
// Old (v3)
var scopes = request.ScopesRequested;

// New (v4+)
var scopes = request.ValidatedResources.RawScopeValues;
```

## Summary

| Approach | Effort | Coverage |
|----------|--------|----------|
| **Fresh start** (`dotnet new duende-is-ui`) + port customizations | Medium | Full — includes all new UI flows |
| **Incremental diff** — compare existing UI with Duende templates | Medium-High | Full if thorough |
| **Minimum viable** — update namespaces only | Low | Partial — compiles but misses new flows |
