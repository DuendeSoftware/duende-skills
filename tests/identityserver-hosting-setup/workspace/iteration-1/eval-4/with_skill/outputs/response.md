# Fixing Discovery Document and Cookie Issues Behind Nginx

## The Problem

When IdentityServer runs behind Nginx that terminates TLS, the proxy strips the original HTTPS scheme and host. ASP.NET Core sees the internal HTTP request, causing:

1. **Discovery document shows `http://` URLs** — IdentityServer generates URLs based on the incoming request scheme, which is `http` after the proxy
2. **Cookies missing `Secure` attribute** — Without HTTPS, cookies don't get the `Secure` flag, which breaks `SameSite=None` behavior

The root cause is that the **reverse proxy strips the original scheme and host headers**, and IdentityServer doesn't know the request originally came via HTTPS.

## Solution

### Option 1: Explicit Configuration

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // Add your Nginx proxy IP
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// IMPORTANT: UseForwardedHeaders MUST come early, before UseIdentityServer
app.UseForwardedHeaders();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

### Option 2: Environment Variable (Simpler for Cloud/Kubernetes)

Set the `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` environment variable. This automatically configures the ForwardedHeaders middleware without any code changes.

This is the simplest approach for cloud-hosted and Kubernetes environments where you don't need fine-grained proxy control.

## Key Points

1. **`UseForwardedHeaders()` must come early** in the pipeline, before `UseIdentityServer()`. If it runs too late, IdentityServer will already have used the wrong scheme.

2. **`ForwardedHeaders.XForwardedProto`** restores the original HTTPS scheme, fixing the discovery document URLs and enabling the `Secure` cookie attribute.

3. **Nginx config** must set the forwarded headers:
   ```nginx
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header X-Forwarded-Host $host;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   ```
