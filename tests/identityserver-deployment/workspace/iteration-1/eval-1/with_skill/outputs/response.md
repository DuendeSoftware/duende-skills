# Fixing HTTP URLs in the Discovery Document Behind Nginx

## The Problem

When IdentityServer runs behind a reverse proxy (like Nginx) that terminates TLS, the middleware sees the internal HTTP request — not the original HTTPS request from the client. This causes the discovery document at `/.well-known/openid-configuration` to publish `http://` URLs instead of `https://`.

The root cause is that ASP.NET Core doesn't automatically read the `X-Forwarded-Proto` and `X-Forwarded-Host` headers that Nginx sets. You need to configure the **ForwardedHeaders middleware** to process these headers.

## Solution: Configure ForwardedHeaders Middleware

### Option 1: Explicit Configuration (Recommended for Production)

Update your `Program.cs` to configure and use `ForwardedHeadersOptions`:

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers for reverse proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // Add the IP address of your Nginx proxy
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5")); // Replace with your Nginx IP

    // Or use a network range if your proxy IP may vary
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 16));

    // Number of proxies in front of the app
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// IMPORTANT: ForwardedHeaders middleware MUST run before IdentityServer middleware
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Option 2: Environment Variable (Simplest)

Alternatively, set the `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` environment variable. This automatically adds the ForwardedHeaders middleware and accepts forwarded headers from any single proxy. This is convenient for cloud-hosted environments and Kubernetes but offers less control.

```bash
# In your deployment configuration (e.g., Kubernetes manifest, Docker Compose)
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

## Key Points

### Middleware Ordering

The `UseForwardedHeaders()` call **must come before** `UseIdentityServer()` in the pipeline. If it runs after IdentityServer has already processed the request, the scheme and host corrections won't be applied, and the discovery document will still show `http://` URLs.

### KnownProxies and KnownNetworks

By default, ASP.NET Core only trusts proxies on localhost (`127.0.0.1/8` and `::1`). This works for local development, but **in production you must explicitly configure the IP addresses of your proxy servers**:

- **`KnownProxies`**: Add specific IP addresses of your proxy servers
- **`KnownNetworks`**: Add CIDR ranges if proxy IPs may vary within a subnet

If you don't configure these, the ForwardedHeaders middleware will silently ignore the forwarded headers from untrusted proxies.

### Why XForwardedProto Is Critical

The `ForwardedHeaders.XForwardedProto` flag is the one that specifically fixes the `http://` vs `https://` issue. When Nginx terminates TLS and forwards the request to Kestrel over HTTP, it sets `X-Forwarded-Proto: https`. The middleware reads this header and sets `HttpContext.Request.Scheme = "https"`, which IdentityServer then uses to generate correct URLs in the discovery document.

## Verification

After deploying the change, verify by hitting the discovery endpoint:

```bash
curl https://your-domain/.well-known/openid-configuration | jq .issuer
```

The `issuer` and all endpoint URLs should now show `https://` instead of `http://`.
