# UI Migration for IdentityServer4 to Duende

The Quickstart UI templates need to be updated when migrating to Duende IdentityServer.

## Namespace Updates

Update all `@using` directives in your Razor views:
- Change `@using IdentityServer4` to `@using Duende.IdentityServer` in `_ViewImports.cshtml` and individual view files

## Template Updates

Duende provides updated UI templates. You can scaffold them with:
```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

Then compare the new templates with your existing customized UI and merge the changes.

## Controller Updates

Your existing MVC controllers should still work after updating namespaces, but you may need to update some API calls if the interface has changed between versions.
