# Migrating the UI from IdentityServer4 to Duende IdentityServer

## Update Razor View Namespaces

Update `@using IdentityServer4` to `@using Duende.IdentityServer` in your view files:

### _ViewImports.cshtml
```cshtml
@using Duende.IdentityServer
```

Check all `.cshtml` files for these namespace references.

## Consider Using Duende Templates

Duende provides updated UI templates that you can scaffold:

```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

The Duende templates are based on Razor Pages rather than MVC controllers, which is a significant architectural change from the IdentityServer4 Quickstart UI.

## Keep Existing MVC UI

Your existing MVC controllers and views will still work after updating namespaces. The core APIs for login, consent, and logout are similar. You may need to update some property names that changed between versions.

## New Flows

Duende IdentityServer supports additional flows like device authorization that the old Quickstart UI didn't include.
