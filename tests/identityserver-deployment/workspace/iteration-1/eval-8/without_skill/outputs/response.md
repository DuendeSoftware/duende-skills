# Fixing ForwardedHeaders with Cloudflare and Nginx

With two proxies, you need to configure ASP.NET Core to trust both.

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto;

    // Clear defaults and trust all proxies
    options.KnownProxies.Clear();
    options.KnownNetworks.Clear();
    options.ForwardLimit = null; // No limit
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();

app.Run();
```

By clearing KnownProxies and KnownNetworks and setting ForwardLimit to null, you trust all forwarded headers. This should fix the discovery document showing incorrect values.
