# Fixing ForwardedHeaders with Multiple Reverse Proxies (Cloudflare -> Nginx -> IdentityServer)

## The Problem

With two proxies in the chain, the default ForwardedHeaders configuration fails because:

1. **`ForwardLimit` defaults to 1** — This means the middleware only processes forwarded headers from a single proxy. With Cloudflare in front of Nginx, there are two sets of forwarded headers. The middleware only reads the innermost proxy's headers (Nginx), but if Nginx doesn't rewrite the `X-Forwarded-Host` header, the original host from Cloudflare is lost.

2. **Only trusted proxies are processed** — Both Cloudflare and Nginx must be added to `KnownProxies` or `KnownNetworks`. If either is missing, the middleware skips its forwarded headers.

3. **XForwardedHost must be included** — If the discovery document shows the wrong *host* (not just wrong scheme), you need `ForwardedHeaders.XForwardedHost` in addition to `XForwardedProto`.

## Solution

Configure ForwardedHeaders to handle the full proxy chain:

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Include both XForwardedProto (for HTTPS) and XForwardedHost (for correct hostname)
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // Set ForwardLimit to 2 — matching the number of proxies in the chain
    // Default is 1, which only processes headers from a single proxy
    options.ForwardLimit = 2;

    // Add BOTH proxy IP addresses to KnownProxies
    // Nginx (your internal proxy)
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));  // Replace with Nginx IP

    // Cloudflare (external proxy) — use their IP ranges
    // Cloudflare publishes their IP ranges at https://www.cloudflare.com/ips/
    // You can add specific IPs or use KnownNetworks for ranges
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("103.21.244.0"), 22));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("103.22.200.0"), 22));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("103.31.4.0"), 22));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("141.101.64.0"), 18));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("108.162.192.0"), 18));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("190.93.240.0"), 20));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("188.114.96.0"), 20));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("197.234.240.0"), 22));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("198.41.128.0"), 17));
    // ... add all Cloudflare ranges
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// ForwardedHeaders MUST come before IdentityServer middleware
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Why ForwardLimit = 2 Is Required

The `ForwardLimit` property controls how many entries the middleware processes from the `X-Forwarded-*` headers. Each proxy in the chain appends its own entry:

```
Client -> Cloudflare -> Nginx -> IdentityServer

X-Forwarded-Proto: https, https
X-Forwarded-Host: myapp.example.com, myapp.example.com
X-Forwarded-For: <client-ip>, <cloudflare-ip>
```

With the default `ForwardLimit = 1`, the middleware only processes the rightmost entry (from Nginx). If Nginx doesn't set `X-Forwarded-Host`, the host is not corrected. With `ForwardLimit = 2`, both proxy entries are processed, ensuring the original client values from Cloudflare are used.

## Why Both Proxies Must Be Trusted

The ForwardedHeaders middleware processes headers from right to left. For each entry, it checks whether the source IP is in `KnownProxies` or `KnownNetworks`. If an untrusted IP is encountered, processing stops. So:

1. **Nginx** must be trusted — otherwise the middleware won't process any forwarded headers
2. **Cloudflare** must be trusted — otherwise processing stops after Nginx's entry, and the original values from Cloudflare are ignored

Each proxy in the chain must be explicitly trusted for the forwarded headers to be fully processed.

## Verification

After deploying:

```bash
curl https://myapp.example.com/.well-known/openid-configuration | jq '{issuer, authorization_endpoint}'
```

Both the issuer and all endpoints should show the correct `https://myapp.example.com` host.
