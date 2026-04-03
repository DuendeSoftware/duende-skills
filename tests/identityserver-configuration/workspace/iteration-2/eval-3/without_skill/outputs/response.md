To prevent tokens for one API from being used at another, you can set up separate API resources. Here's how you might configure this:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("read", "Read access"),
        new ApiScope("write", "Write access")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("catalog-api", "Catalog API")
        {
            Scopes = { "read", "write" }
        },
        new ApiResource("orders-api", "Orders API")
        {
            Scopes = { "read" }
        }
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

Each API Resource defines a logical boundary. The tokens should include audience information based on the resource definitions. The catalog-api gets both read and write, while orders-api only gets read.
