# Namespace changes when migrating from IdentityServer4 to Duende

The good news is that Duende IdentityServer kept the same API surface as IdentityServer4, so almost all of the migration is a mechanical namespace rename. Every `IdentityServer4.*` namespace gets a `Duende.` prefix, and the separate `IdentityModel` library was also rebranded to `Duende.IdentityModel`.

## Mapping for the namespaces you listed

| Old | New |
|-----|-----|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityModel` | `Duende.IdentityModel` |

The pattern is simply: prefix `IdentityServer4` with `Duende.`, and rename `IdentityModel` to `Duende.IdentityModel`.

## In your files

`Config.cs`:

```csharp
using Duende.IdentityServer.Models;   // was: using IdentityServer4.Models;
```

`Program.cs`:

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;  // was IdentityServer4.EntityFramework.DbContexts
using Duende.IdentityServer.EntityFramework.Mappers;     // was IdentityServer4.EntityFramework.Mappers
using Duende.IdentityServer.Models;                      // was IdentityServer4.Models
```

## Doing it across the codebase

Since it's a consistent prefix change you can run a global find-and-replace:

1. First replace `IdentityModel` → `Duende.IdentityModel` (it's a different package, so handle it separately).
2. Then replace `IdentityServer4` → `Duende.IdentityServer` everywhere.

Use a whole-word match (regex `\bIdentityServer4\b`) so you don't accidentally rewrite substrings, and remember to check `.cshtml` `@using` directives and any fully-qualified type names, not just the `using` statements at the top of `.cs` files. Compile afterward and the compiler will flag anything you missed.
