# Namespace changes: IdentityServer4 → Duende IdentityServer

Duende IdentityServer is the direct successor to IdentityServer4, and the namespaces map one-to-one: every `IdentityServer4.*` namespace becomes `Duende.IdentityServer.*`, and the separate `IdentityModel` package becomes `Duende.IdentityModel`.

## Complete namespace mapping

| IdentityServer4 (old) | Duende IdentityServer (new) |
|-----------------------|-----------------------------|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.Stores` | `Duende.IdentityServer.Stores` |
| `IdentityServer4.Extensions` | `Duende.IdentityServer.Extensions` |
| `IdentityServer4.Events` | `Duende.IdentityServer.Events` |
| `IdentityServer4.Test` | `Duende.IdentityServer.Test` |
| `IdentityServer4.Validation` | `Duende.IdentityServer.Validation` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityServer4.EntityFramework.Options` | `Duende.IdentityServer.EntityFramework.Options` |
| `IdentityModel` | `Duende.IdentityModel` |

The general rule: **`IdentityServer4` → `Duende.IdentityServer`** as a prefix, and the standalone **`IdentityModel` → `Duende.IdentityModel`**.

## Applied to your files

**`Config.cs`** — one directive to change:

```csharp
// Old
using IdentityServer4.Models;

// New
using Duende.IdentityServer.Models;
```

The model types (`IdentityResource`, `ApiScope`, `ApiResource`, `Client`, `Secret`, `GrantTypes`) keep the same names.

**`Program.cs`** — three directives to change:

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

## Search-and-replace guidance

Because the change is a consistent prefix rename, you can do it across the whole codebase safely. Do the more specific replacements before the broad one, or use a word-boundary regex:

1. Replace `using IdentityModel` → `using Duende.IdentityModel` (do this first so it isn't caught by the IdentityServer4 rule — note they are different packages).
2. Replace `IdentityServer4` → `Duende.IdentityServer` everywhere (namespaces, fully-qualified type references, and `@using` directives in any `.cshtml` files).

A regex like `\bIdentityServer4\b` → `Duende.IdentityServer` avoids partial matches. Also check fully-qualified type references in code and configuration, not just the `using` block. After replacing, rebuild — any remaining `IdentityServer4` reference will surface as a compile error you can fix directly.
