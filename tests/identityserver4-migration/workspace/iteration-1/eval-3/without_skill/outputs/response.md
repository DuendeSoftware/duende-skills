# Namespace Changes: IdentityServer4 to Duende IdentityServer

The namespace migration is straightforward — replace the `IdentityServer4` prefix with `Duende.IdentityServer`:

| Old | New |
|-----|-----|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |

For `IdentityModel`, the replacement is:

| Old | New |
|-----|-----|
| `IdentityModel` | `Duende.IdentityModel` |

## Quick Replace

You can do a global find-and-replace:

```
Find:    IdentityServer4
Replace: Duende.IdentityServer
```

And separately:
```
Find:    using IdentityModel;
Replace: using Duende.IdentityModel;
```

This covers all the sub-namespaces automatically since the prefix replacement cascades.
