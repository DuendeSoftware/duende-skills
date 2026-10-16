Scope names are global, so a shared name like `read` can't be configured per-API on its own. Use API Resources to give each API its own audience, and resource isolation (RFC 8707) so tokens are single-audience:

```csharp
using Duende.IdentityServer.Models;

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("read",  "Read data"),
        new ApiScope("write", "Write data")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("catalog-api", "Catalog API")
        {
            Scopes = { "read", "write" },
            RequireResourceIndicator = true   // audience only included when explicitly requested
        },
        new ApiResource("orders-api", "Orders API")
        {
            Scopes = { "read" },
            RequireResourceIndicator = true
        }
    });
```
Client requests, using the `resource` parameter:
- `scope=read write&resource=catalog-api` → `aud: catalog-api`
- `scope=read&resource=orders-api` → `aud: orders-api`

Each API validates that its own name is in `aud`, so a catalog token is rejected at orders-api and vice versa. Without resource indicators, requesting the shared `read` scope would put both audiences in the token (`["catalog-api","orders-api"]`), defeating isolation. Resource isolation is an Enterprise Edition feature. Clients must have `read`/`write` in `AllowedScopes`. If you can't use resource indicators, rename the scopes (`catalog.read`, `orders.read`) so they are not shared.
