# Migrating the IdentityServer4 Quickstart UI

When migrating your IdentityServer4 Quickstart UI to Duende IdentityServer, you'll need to make several changes:

## 1. Update Namespace References

Update all `@using IdentityServer4` directives in your Razor files to `@using Duende.IdentityServer`:

- `_ViewImports.cshtml`: Change `@using IdentityServer4` to `@using Duende.IdentityServer`
- Check individual `.cshtml` files for any additional IdentityServer4 namespace references

## 2. Update Controller Namespaces

In your `AccountController.cs`, `ConsentController.cs`, and other controllers, update `using` statements from `IdentityServer4.*` to `Duende.IdentityServer.*`.

## 3. Consider Using Updated Templates

Duende provides updated UI templates that you can scaffold into your project. Consider starting fresh with the Duende templates and porting your customizations over:

```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```

This will give you the latest version of the UI that's designed for Duende IdentityServer.

## 4. Review for API Changes

Some IdentityServer APIs may have changed between versions. Review your controllers for any breaking changes in the interaction service or model types.

## 5. Test Thoroughly

After making the changes:
- Test login/logout flows
- Test consent screens
- Test error handling pages
- Verify all styling and customizations still work correctly
