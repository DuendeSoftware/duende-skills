# Namespace Migration: IdentityServer4 to Duende IdentityServer

Here's the complete namespace mapping:

| Old Namespace | New Namespace |
|---|---|
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

### Search and Replace

Use IDE-wide search and replace across your solution:

1. Replace `using IdentityServer4` with `using Duende.IdentityServer` (this catches all sub-namespaces)
2. Replace `using IdentityModel` with `using Duende.IdentityModel`
3. Also check for fully-qualified type references like `IdentityServer4.Models.Client` → `Duende.IdentityServer.Models.Client`
4. Check `_ViewImports.cshtml` and `.cshtml` files for `@using IdentityServer4` directives
