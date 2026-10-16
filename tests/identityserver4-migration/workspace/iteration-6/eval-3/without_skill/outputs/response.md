## Namespace mapping

| IdentityServer4 | Duende IdentityServer |
|---|---|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.Models` | `Duende.IdentityServer.Models` |
| `IdentityServer4.Services` | `Duende.IdentityServer.Services` |
| `IdentityServer4.EntityFramework.DbContexts` | `Duende.IdentityServer.EntityFramework.DbContexts` |
| `IdentityServer4.EntityFramework.Mappers` | `Duende.IdentityServer.EntityFramework.Mappers` |
| `IdentityModel` | `Duende.IdentityModel` (IdentityModel v7+) |

Other prefixes follow the same pattern (`IdentityServer4.Stores`, `.Validation`, `.Events`, `.Extensions`, `.Configuration`, `.EntityFramework.Entities`, `.EntityFramework.Options`, `IdentityServer4.AspNetIdentity`).

Do it with a solution-wide find/replace: `IdentityServer4.` → `Duende.IdentityServer.`, then bare `using IdentityServer4;` → `using Duende.IdentityServer;`. Also update Razor `_ViewImports.cshtml`. For `IdentityModel`, replace `using IdentityModel;` with `using Duende.IdentityModel;` and update the package to `Duende.IdentityModel`.

For your Program.cs:
```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
```
Config.cs: `using Duende.IdentityServer.Models;`. Take care that the `Sha256()` extension lives in `Duende.IdentityServer.Models` (`Secret` extensions) so the Config file still compiles.
