# Migrating the Quickstart UI to Duende IdentityServer

Your project has the classic IdentityServer4 **Quickstart UI**: MVC `AccountController`/`ConsentController` with Razor views under `Views/Account/` and `Views/Consent/`, plus a `_ViewImports.cshtml` with `@using IdentityServer4`. Here's what to do with it.

## 1. Update namespaces in the views

Every `@using IdentityServer4` directive in `.cshtml` files must become `@using Duende.IdentityServer`. Start with `_ViewImports.cshtml`:

```cshtml
@* Old *@
@using IdentityServer4

@* New *@
@using Duende.IdentityServer
```

Then check individual view files and the controllers for any `using IdentityServer4.*` statements and update those too.

## 2. Fix v4 API changes in the controllers/views

The Quickstart UI calls `IIdentityServerInteractionService`, and several members changed. Update your `AccountController`/`ConsentController` (and any view code) accordingly:

- `request.ClientId` → **`request.Client.ClientId`** (the `AuthorizationRequest` exposes the full `Client`)
- `ConsentResponse.ScopesConsented` → **`ScopesValuesConsented`** (renamed property)
- `GetAllUserConsentsAsync()` → **`GetAllUserGrantsAsync()`**
- `IsPkceClientAsync(...)` → use `context.IsNativeClient()` / `request.Client.RequirePkce`

## 3. Know that the UI has diverged significantly

Duende's current templates use **Razor Pages** (`Pages/`) rather than the older **MVC controllers + Views** layout, and the CSS/JS has been refreshed. Your existing **MVC-based UI will still compile and work** after the namespace and API updates above — but it will **miss the newer UI flows** that Duende added and that never existed in IdentityServer4, such as **device flow authorization, CIBA (backchannel authentication), dynamic identity provider management, and server-side session management**.

## Recommended approaches

1. **Preferred — start fresh** with the Duende templates and port your customizations:
   ```bash
   dotnet new install Duende.Templates
   dotnet new duende-is-ui
   ```
   This scaffolds the current Duende UI (Razor Pages, new flows). Diff it against your existing UI to see where your customizations belong.

2. **Incremental** — diff your current UI against the Duende templates and apply changes surgically. Good when your UI is heavily customized.

3. **Minimum viable** — just update the `@using` directives and fix the v4 API changes so the project compiles and runs, and defer the full refresh. You'll stay on the older layout and won't get the new pages.

If this particular host actually has **no UI** (some IS4 projects are headless — stores/clients/migrations only), you can skip UI work entirely.
