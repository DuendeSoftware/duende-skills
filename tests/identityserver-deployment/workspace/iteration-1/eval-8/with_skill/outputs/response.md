# Fixing ForwardedHeaders with Multiple Proxies (Cloudflare -> Nginx -> IdentityServer)

## The Issue

With two proxies in the chain (Cloudflare -> Nginx -> IdentityServer), the default `ForwardLimit` of `1` only processes forwarded headers from the last proxy (Nginx). But the correct original values may be set by the first proxy (Cloudflare), and you need the middleware to process both layers.

Additionally, both proxy IP addresses must be trusted (added to `KnownProxies` or `KnownNetworks`), otherwise the middleware ignores headers from untrusted sources.

## Solution

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Process headers from BOTH proxies in the chain
    options.ForwardLimit = 2;

    // Include XForwardedHost to fix incorrect host name in discovery
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost |
                                ForwardedHeaders.XForwardedFor;

    // Trust BOTH proxy IP addresses
    // Cloudflare IP ranges (example — use actual Cloudflare ranges)
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("103.21.244.0"), 22));
    // ... add all Cloudflare IP ranges from https://www.cloudflare.com/ips/

    // Nginx proxy IP
    options.KnownProxies.Add(IPAddress.Parse("10.0.1.50"));
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// Must run before IdentityServer
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Configuration Points

### 1. ForwardLimit = 2

The `ForwardLimit` controls how many proxy hops the middleware processes from right to left in the `X-Forwarded-*` headers. The default is `1`, meaning it only processes the most recent proxy entry.

With Cloudflare -> Nginx -> IdentityServer, you have **2 proxies**, so `ForwardLimit` must be `2`. If set to `1`, the middleware only processes Nginx's entry and may still see incorrect values because Cloudflare's original values are ignored.

### 2. Trust Both Proxies

Each proxy in the chain must be trusted by adding its IP to `KnownProxies` or its network range to `KnownNetworks`. The ForwardedHeaders middleware skips entries from untrusted IPs:

- **Cloudflare**: Uses dynamic IP ranges. Add them via `KnownNetworks` using the ranges from Cloudflare's published IP list.
- **Nginx**: Use the internal IP of your Nginx instance in `KnownProxies`.

If a proxy IP isn't in `KnownProxies` or `KnownNetworks`, its forwarded header entry is **silently ignored**, which explains why your current configuration isn't working.

### 3. XForwardedHost for Correct Host Name

Including `ForwardedHeaders.XForwardedHost` is important when the discovery document shows the wrong host name. Cloudflare and Nginx may set `X-Forwarded-Host` to the original public hostname, and the middleware needs to read this to restore the correct `Request.Host`.

### Header Flow Example

```
Client -> Cloudflare (203.0.113.1) -> Nginx (10.0.1.50) -> IdentityServer

X-Forwarded-Proto: https, https
X-Forwarded-Host: identity.example.com, identity.example.com
X-Forwarded-For: client-ip, 203.0.113.1
```

With `ForwardLimit = 2`, the middleware processes both entries and correctly sets `Request.Scheme = "https"` and `Request.Host = "identity.example.com"`.
