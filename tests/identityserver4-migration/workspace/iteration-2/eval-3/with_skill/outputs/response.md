# Namespace Migration: IdentityServer4 → Duende.IdentityServer

Here is the complete mapping of all the namespaces you listed:

| Old Namespace | New Namespace |
|---|---|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityModel` | `Duende.IdentityModel` |

## Search and Replace

You can do a global search-and-replace across your solution. The key replacements are:

```
IdentityServer4.EntityFramework  →  Duende.IdentityServer.EntityFramework
IdentityServer4                  →  Duende.IdentityServer
IdentityModel                   →  Duende.IdentityModel
```

**Order matters** — replace the longer prefixes first (e.g. `IdentityServer4.EntityFramework` before `IdentityServer4`) to avoid partial replacements.

### Example: Config.cs

```csharp
// Old
using IdentityServer4.Models;

// New
using Duende.IdentityServer.Models;
```

### Example: Program.cs

```csharp
// Old
using IdentityServer4.EntityFramework.DbContexts;
using IdentityServer4.EntityFramework.Mappers;
using IdentityServer4.Models;

// New
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
```

### Additional Namespaces

If you have other `IdentityServer4.*` namespaces elsewhere, they follow the same pattern:

| Old | New |
|---|---|
| `IdentityServer4.Stores` | `Duende.IdentityServer.Stores` |
| `IdentityServer4.Extensions` | `Duende.IdentityServer.Extensions` |
| `IdentityServer4.Events` | `Duende.IdentityServer.Events` |
| `IdentityServer4.Test` | `Duende.IdentityServer.Test` |
| `IdentityServer4.Validation` | `Duende.IdentityServer.Validation` |
| `IdentityServer4.EntityFramework.Options` | `Duende.IdentityServer.EntityFramework.Options` |

Also update any fully-qualified type references in code, configuration files, and `@using` directives in `.cshtml` Razor views.
