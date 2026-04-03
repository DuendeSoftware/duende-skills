# Multiple Proxies in Chain: Cloudflare -> Nginx -> IdentityServer

## The Issue

With multiple proxies in a chain, the default `ForwardLimit` of `1` means ASP.NET Core only processes forwarded headers from a single proxy (the most recent one). Since you have **two** proxies (Cloudflare and Nginx), you need to:

1. Set `ForwardLimit` to `2` to match the number of proxies in the chain
2. Add **both** proxy IP addresses to `KnownProxies` or their network ranges to `KnownNetworks`
3. Include `ForwardedHeaders.XForwardedHost` to fix the incorrect host name

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Include both XForwardedHost and XForwardedProto
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                                ForwardedHeaders.XForwardedProto;

    // CRITICAL: Set ForwardLimit to 2 because there are 2 proxies in the chain.
    // The default of 1 only processes headers from a single proxy.
    options.ForwardLimit = 2;

    // Each proxy in the chain must be trusted. Add both proxy IPs.
    options.KnownProxies.Add(IPAddress.Parse("198.51.100.1"));  // Cloudflare edge IP
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));      // Nginx internal IP
    
    // Alternatively, use KnownNetworks for ranges:
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("198.51.100.0"), 24));
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 16));
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// ForwardedHeaders must be first in the pipeline
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`ForwardLimit = 2`**: Matches the number of proxies (Cloudflare + Nginx). The default of `1` only processes headers from the nearest proxy, which is why your discovery document still shows the wrong host.

2. **Both proxy IPs in KnownProxies**: Each proxy in the chain must be added to `KnownProxies` or `KnownNetworks`. For the forwarded headers to be processed, every hop must be trusted.

3. **`XForwardedHost`**: Without this, even if `XForwardedProto` fixes the scheme, the host name in the discovery document may still be wrong (e.g., showing an internal hostname instead of the public domain).

4. **Pipeline ordering**: `UseForwardedHeaders()` must run before `UseIdentityServer()`.
