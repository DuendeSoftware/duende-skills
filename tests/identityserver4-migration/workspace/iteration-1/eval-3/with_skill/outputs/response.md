# Namespace Migration: IdentityServer4 → Duende IdentityServer

Here is the complete mapping of all the namespaces you mentioned, plus additional common ones:

## Namespace Mapping Table

| Old Namespace | New Namespace |
|---------------|--------------|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.Stores` | `Duende.IdentityServer.Stores` |
| `IdentityServer4.Events` | `Duende.IdentityServer.Events` |
| `IdentityServer4.Extensions` | `Duende.IdentityServer.Extensions` |
| `IdentityServer4.Test` | `Duende.IdentityServer.Test` |
| `IdentityServer4.Validation` | `Duende.IdentityServer.Validation` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityServer4.EntityFramework.Options` | `Duende.IdentityServer.EntityFramework.Options` |
| `IdentityModel` | `Duende.IdentityModel` |

## Search and Replace Strategy

The simplest approach is a two-pass find-and-replace across your entire codebase:

### Pass 1: IdentityServer4 namespaces
```
Find:    IdentityServer4
Replace: Duende.IdentityServer
```

This single replacement handles all sub-namespaces because `IdentityServer4.Models` becomes `Duende.IdentityServer.Models`, `IdentityServer4.EntityFramework.DbContexts` becomes `Duende.IdentityServer.EntityFramework.DbContexts`, etc.

### Pass 2: IdentityModel
```
Find:    using IdentityModel;
Replace: using Duende.IdentityModel;
```

**Important:** Do the `IdentityModel` replacement separately and be more specific (include `using` and `;`) to avoid accidentally replacing `IdentityModel` substrings in other contexts.

### Files to Check

For your specific project files:

**Program.cs** — Update these:
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

**Config.cs** — Update:
```csharp
// Old
using IdentityServer4.Models;

// New
using Duende.IdentityServer.Models;
```

### Also Check
- `_ViewImports.cshtml` and Razor views for `@using IdentityServer4` directives
- Fully-qualified type references in code (e.g., `IdentityServer4.Models.Client` → `Duende.IdentityServer.Models.Client`)
- Configuration files that reference IdentityServer4 type names
- XML doc comments or string literals containing namespace references
