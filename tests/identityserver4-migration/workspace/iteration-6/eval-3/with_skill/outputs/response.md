## Namespace changes

Replace every `IdentityServer4` namespace with `Duende.IdentityServer`; the sub-namespaces stay the same. `IdentityModel` becomes `Duende.IdentityModel`.

| Old | New |
|---|---|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityModel` | `Duende.IdentityModel` |

Others in the same pattern: `.Stores`, `.Extensions`, `.Events`, `.Test`, `.Validation`, `.EntityFramework.Options`.

```csharp
// Program.cs
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;

// Config.cs
using Duende.IdentityServer.Models;
```

Tips:
- Do a solution-wide search/replace of `using IdentityServer4` → `using Duende.IdentityServer` and `using IdentityModel;` → `using Duende.IdentityModel;`.
- Also update **fully-qualified type references** in code and configuration files, and `@using IdentityServer4` in `.cshtml` / `_ViewImports.cshtml`.
- Package renames must accompany this (`Duende.IdentityServer`, `Duende.IdentityServer.EntityFramework`, `Duende.IdentityModel`), plus the framework upgrade (net8.0 for v7, net10.0 for v8).
- Symptom of an incomplete change: "`IdentityServer4` namespace not found" after the package swap.
