## UI migration

The Quickstart UI is your code, so Duende won't change it for you. You need to:

1. **Update namespaces** in controllers and views: `using IdentityServer4;` → `using Duende.IdentityServer;`, `IdentityServer4.Models` → `Duende.IdentityServer.Models`, `IdentityServer4.Services` → `Duende.IdentityServer.Services`, `IdentityServer4.Events`, `IdentityServer4.Extensions`, `IdentityServer4.Stores`, `IdentityServer4.Validation`, etc.
2. **`_ViewImports.cshtml`**: change `@using IdentityServer4` to `@using Duende.IdentityServer`. Otherwise Razor compilation fails.
3. **Controllers** (AccountController, ConsentController, etc.) keep working as MVC; fix compile errors from API changes (`IIdentityServerInteractionService`, `IEventService`, `IClientStore`, `IdentityServerUser`).
4. Update `IdentityModel` references to `Duende.IdentityModel`.
5. Optionally replace the MVC quickstart with the newer Razor Pages templates from `Duende.IdentityServer.Templates` (`dotnet new isui`), copying your branding across.
6. In Startup, the `MapDefaultControllerRoute()` mapping stays; with Razor Pages add `AddRazorPages()`/`MapRazorPages()`.
7. Check cookie names, `SameSite` and logout flows after migrating; test login, consent, logout, and error pages.
