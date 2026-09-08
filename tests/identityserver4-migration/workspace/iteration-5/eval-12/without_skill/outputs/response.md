# What to do with the Quickstart UI when migrating to Duende

Your login/consent UI is the IdentityServer4 Quickstart: MVC controllers (`AccountController`, `ConsentController`) with Razor views under `Views/Account/` and `Views/Consent/`, and a `_ViewImports.cshtml` importing `@using IdentityServer4`. It won't break dramatically, but it does need attention.

## Update the namespaces in your Razor files

The most immediate change is the same namespace rename you're doing in the rest of the code, applied to the views. In `_ViewImports.cshtml`:

```cshtml
@* was *@
@using IdentityServer4

@* becomes *@
@using Duende.IdentityServer
```

Do the same for any `@using IdentityServer4.*` directives in individual `.cshtml` files, and update the `using` statements in `AccountController`/`ConsentController`.

## Your existing MVC UI will keep working — with caveats

After the namespace updates, the controller-and-views UI you have will still compile and run against Duende. However, the Duende UI templates have moved on considerably from the 2018-era Quickstart. Notably, the current Duende templates are built as **Razor Pages** rather than MVC controllers + views, and the layout/styling has been modernized. Sticking with your MVC UI is fine, but you won't automatically get the **newer flows** that Duende ships in its templates — things like **device flow, CIBA (backchannel authentication), and dynamic external provider management** — because those pages simply don't exist in the old Quickstart.

Also review the interaction-service calls in your controllers for any API surface changes and make sure they still compile against the Duende types.

## Recommended approach

The cleanest option is usually to **scaffold the current Duende UI templates into a throwaway project (or your project) and port your customizations over**, rather than hand-patching the old Quickstart:

```bash
dotnet new install Duende.Templates
dotnet new <duende UI template>
```

Then diff the generated Razor Pages UI against your customized Quickstart and bring across the bits you changed (branding, extra fields, custom logic). If your customizations are extensive, do it incrementally with a diff tool instead. And if you just need to keep running for now, the namespace-only update is enough to get you compiling, with the fuller UI refresh deferred.
