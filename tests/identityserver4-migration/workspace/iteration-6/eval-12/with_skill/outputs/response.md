## UI migration to Duende IdentityServer

Your Quickstart UI (MVC controllers + Razor views) will still compile and work after a namespace update, but it has diverged from Duende's templates. You have three options.

### 1. Minimum viable update (just get it running)
- In `_ViewImports.cshtml` and any `.cshtml`: `@using IdentityServer4` → `@using Duende.IdentityServer`.
- In controllers (AccountController, ConsentController, etc.) update usings: `IdentityServer4`, `.Models`, `.Services`, `.Stores`, `.Events`, `.Extensions`, `.Validation`, `.Test` → `Duende.IdentityServer.*`; `IdentityModel` → `Duende.IdentityModel`.
- Check for v4-era API usage (if left from v3): `request.ClientId` → `request.Client.ClientId`, `ScopesConsented` → `ScopesValuesConsented`, `GetAllUserConsentsAsync` → `GetAllUserGrantsAsync`.
- Keep `MapDefaultControllerRoute()` mapping.

This leaves you on the older layout and misses newer flows.

### 2. Preferred: start fresh with Duende templates and port customizations
```bash
dotnet new install Duende.Templates
dotnet new duende-is-ui
```
Duende's templates use **Razor Pages** (`Pages/`) rather than controllers + views, and include device flow, CIBA, dynamic identity provider and server-side session management pages, with refreshed CSS/JS. Diff the output against your UI to place your customizations (branding, login logic, consent).

### 3. Incremental
Diff your UI against the templates and apply changes surgically — good for heavy customizations.

If you add Razor Pages, call `AddRazorPages()` / `MapRazorPages()` in your Program.cs alongside (or instead of) the controllers.

Also update the rest of the host as part of the same migration (packages, net8.0/net10.0 target, license key, EF migrations).
