# IdentityServer Behind Nginx Reverse Proxy

## Problem

When IdentityServer sits behind Nginx that terminates TLS:
- The inner request arrives as HTTP, causing the discovery document to publish `http://` URLs
- Cookies miss the `Secure` attribute because ASP.NET Core sees HTTP, breaking `SameSite` behavior

## Solution

### Option 1: Environment Variable (Simple)

Set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`. This automatically adds the middleware and accepts forwarded headers from any single proxy. Best for cloud/Kubernetes environments.

### Option 2: Explicit Configuration (Production)

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                                ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42")); // Your Nginx IP
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer();

var app = builder.Build();

// Must be early in the pipeline, BEFORE UseIdentityServer()
app.UseForwardedHeaders();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Explanation

- The reverse proxy terminates TLS and forwards requests as HTTP internally. Without `ForwardedHeaders`, IdentityServer sees HTTP and generates HTTP URLs in the discovery document.
- `ForwardedHeaders.XForwardedProto` restores the original HTTPS scheme from the `X-Forwarded-Proto` header.
- `UseForwardedHeaders()` must run early in the pipeline, before `UseIdentityServer()`.
- The `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` environment variable is a simpler alternative that works well for cloud/Kubernetes deployments.
