# Namespace Changes for IdentityServer4 to Duende Migration

The namespace migration is straightforward — replace the `IdentityServer4` prefix with `Duende.IdentityServer`:

## Mappings

| Old | New |
|---|---|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |

## IdentityModel

For `IdentityModel`, the Duende equivalent package is also available:

```
IdentityModel → Duende.IdentityModel
```

You may need to install the `Duende.IdentityModel` NuGet package to get the updated helpers like `JwtClaimTypes` and `OidcConstants`.

## Quick Find-and-Replace

Do a project-wide find-and-replace:

1. `using IdentityServer4` → `using Duende.IdentityServer`
2. `using IdentityModel` → `using Duende.IdentityModel`

The model types like `Client`, `ApiScope`, `ApiResource`, `IdentityResource`, `Secret`, and `GrantTypes` all have the same names — just under the new namespace.
