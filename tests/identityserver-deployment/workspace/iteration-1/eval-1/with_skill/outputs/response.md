# Fixing Discovery Document HTTP URLs Behind Nginx Reverse Proxy

When IdentityServer runs behind a TLS-terminating reverse proxy like Nginx, the middleware sees the internal HTTP request, not the original HTTPS request. This causes the discovery document at `/.well-known/openid-configuration` to advertise `http://` URLs instead of `https://`.

## Root Cause

The reverse proxy terminates TLS and forwards the request to IdentityServer over plain HTTP. ASP.NET Core sees `Request.Scheme = "http"` unless you configure it to read the forwarded headers set by the proxy.

## Solution: Configure ForwardedHeaders Middleware

### Option 1: Environment Variable (Simplest)

Set the `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` environment variable. This automatically adds the ForwardedHeaders middleware and accepts forwarded headers from any single proxy. This is the simplest approach for cloud-hosted or Kubernetes environments.

### Option 2: Explicit Configuration (More Control)

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// Configure ForwardedHeaders
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // In production, add the IP address of your Nginx proxy
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));

    // Or use a network range for dynamic proxy IPs
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));

    // Number of proxies in the chain
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// IMPORTANT: ForwardedHeaders middleware must run BEFORE IdentityServer
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **Pipeline order matters**: `UseForwardedHeaders()` must run **before** `UseIdentityServer()` and before any authentication middleware. Otherwise, IdentityServer will see the unmodified HTTP scheme when generating URLs for the discovery document.

2. **KnownProxies/KnownNetworks**: By default, only `127.0.0.1` (localhost) and `::1` are trusted. In production, you **must** add your Nginx proxy's IP address to `KnownProxies` or add its network range to `KnownNetworks`. If the proxy IP isn't trusted, the forwarded headers are ignored.

3. **XForwardedProto is the critical header**: The `ForwardedHeaders.XForwardedProto` flag is what fixes the `http://` vs `https://` issue. It tells ASP.NET Core to read the `X-Forwarded-Proto` header set by Nginx (which should be `https`) and use that as the request scheme.

4. **Nginx configuration**: Ensure your Nginx config sets the proper headers:
   ```nginx
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header X-Forwarded-Host $host;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   ```

After applying this configuration, the discovery document will correctly show `https://` URLs.
