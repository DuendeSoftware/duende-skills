# Migrating the IdentityServer4 Quickstart UI to Duende IdentityServer

Your MVC-based UI (AccountController, ConsentController, Razor views) needs several updates. Here's a comprehensive approach:

## 1. Update Namespace Directives

Update `@using IdentityServer4` directives in `_ViewImports.cshtml` and any individual `.cshtml` files to `@using Duende.IdentityServer`:

```cshtml
@* Old *@
@using IdentityServer4

@* New *@
@using Duende.IdentityServer
```

Check all Razor view files — not just `_ViewImports.cshtml` — for any direct `IdentityServer4` namespace references.

## 2. Understand the UI Layout Differences

Duende IdentityServer templates now use **Razor Pages** (`Pages/`) instead of MVC controllers (`Controllers/` + `Views/`). The UI architecture has changed significantly since the IdentityServer4 Quickstart UI era. However, your **existing MVC-based UI will still compile and work after the namespace updates** — it just won't include newer UI flows like:

- **Device flow** authorization page
- **CIBA** (Client-Initiated Backchannel Authentication)
- **Dynamic identity provider** management
- **Server-side session** management

## 3. Fix API Changes in Controller Code

Several API surfaces changed between IdentityServer4 v3/v4 and Duende. Update your controller code:

```csharp
// Old (IdentityServer4)
var clientId = request.ClientId;
var scopes = request.ScopesRequested;

// New (Duende)
var clientId = request.Client.ClientId;      // Client is now an object
var scopes = request.ValidatedResources.RawScopeValues;
```

```csharp
// Old
var consent = new ConsentResponse { ScopesConsented = scopes };

// New
var consent = new ConsentResponse { ScopesValuesConsented = scopes };  // renamed
```

## 4. Choose a Migration Approach

### Recommended: Start Fresh with Duende Templates

Scaffold the current Duende UI pages and port your customizations:

```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

This gives you the latest Razor Pages-based UI. Diff the output against your existing controllers/views to identify where your customizations fit.

### Alternative: Incremental Update

If your UI has heavy customizations, update namespaces in all `.cshtml` files, fix the v4 API changes in controllers, and defer the full layout refresh. This is a minimum-viable approach that gets you compiling but leaves you on the older MVC pattern.
