# Fix Discovery Document Showing HTTP URLs Behind Nginx Reverse Proxy

## Problem

When IdentityServer runs behind an Nginx reverse proxy that terminates TLS, the middleware sees the inner HTTP request. This causes the discovery document at `/.well-known/openid-configuration` to publish `http://` URLs instead of `https://`.

## Solution

Configure the ASP.NET Core `ForwardedHeaders` middleware to read the `X-Forwarded-Proto` and `X-Forwarded-Host` headers set by Nginx.

### Option 1: Environment Variable (Simplest)

Set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`. This automatically adds the middleware and accepts forwarded headers from any single proxy. Best for cloud-hosted environments and Kubernetes.

### Option 2: Explicit Configuration (More Control)

Update your `Program.cs`:

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// Configure ForwardedHeaders to handle reverse proxy headers
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                                ForwardedHeaders.XForwardedProto;

    // In production, add your Nginx proxy IP address to KnownProxies.
    // The default only trusts localhost (127.0.0.1/8 and ::1).
    // Without this, headers from non-localhost proxies are ignored.
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1")); // Replace with your Nginx IP

    // Number of proxies in front of the app (default is 1)
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// IMPORTANT: ForwardedHeaders middleware must run EARLY in the pipeline,
// BEFORE IdentityServer middleware and ASP.NET authentication middleware.
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **ForwardedHeaders middleware must run before IdentityServer** in the pipeline. If it runs after, IdentityServer has already processed the request with the wrong scheme.

2. **XForwardedProto** is the critical flag — it restores the original HTTPS scheme from the `X-Forwarded-Proto` header, which fixes the `http://` URLs in the discovery document.

3. **KnownProxies/KnownNetworks**: By default, only localhost is trusted. In production, you must add your Nginx proxy's IP address to `KnownProxies` or its network range to `KnownNetworks`. Without this, forwarded headers from external proxies are silently ignored.

4. **ForwardLimit** defaults to 1, which is correct for a single proxy. If you have multiple proxies, increase this accordingly.
