# Namespace Changes for Duende IdentityServer

The main namespace change is straightforward:

| Old | New |
|---|---|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |

You can do a global find-and-replace of `IdentityServer4` with `Duende.IdentityServer` across your codebase.

For `IdentityModel`, you may also need to update to `Duende.IdentityModel` if you're using it as a client library.
