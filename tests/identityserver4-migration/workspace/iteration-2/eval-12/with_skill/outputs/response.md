# UI Migration: IdentityServer4 Quickstart UI → Duende IdentityServer

## Update Namespace Directives

Update all `@using IdentityServer4` directives in `.cshtml` files and `_ViewImports.cshtml` to `@using Duende.IdentityServer`:

```cshtml
@* Old *@
@using IdentityServer4

@* New *@
@using Duende.IdentityServer
```

Check `_ViewImports.cshtml` and every individual `.cshtml` file.

## Duende Templates Use Razor Pages (Not MVC Controllers)

The Duende IdentityServer templates use **Razor Pages** (`Pages/`) instead of the MVC controller pattern (`Controllers/` + `Views/`). Your existing MVC-based UI will still work after namespace updates, but you will miss newer UI flows including:
- **Device flow authorization** pages
- **CIBA (Client-Initiated Backchannel Authentication)** pages
- **Dynamic identity provider** management pages
- **Server-side session** management pages

## Recommended: Scaffold Fresh Duende Templates

```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

This scaffolds the current Duende UI pages. Diff the output against your existing UI and port your customizations to the new templates.

## Fix API Changes in Controller/Page Model Code

If keeping your existing MVC controllers, fix these v4 API changes:

```csharp
// Old (v3/v4 Quickstart)
var clientId = request.ClientId;
var scopes = request.ScopesRequested;

// New (Duende / IS4 v4+)
var clientId = request.Client.ClientId;
var scopes = request.ValidatedResources.RawScopeValues;
```

```csharp
// Old
var grantedConsent = new ConsentResponse
{
    ScopesConsented = consentedScopes
};

// New
var grantedConsent = new ConsentResponse
{
    ScopesValuesConsented = consentedScopes  // renamed property
};
```

## Summary of Approaches

1. **Preferred**: Start fresh with `dotnet new duende-is-ui` and port customizations
2. **Alternative**: Incremental diff — compare your UI with Duende templates and apply changes surgically
3. **Minimum viable**: Update namespaces in `.cshtml` files, fix v4 API changes in controllers — gets you running but on the older layout
