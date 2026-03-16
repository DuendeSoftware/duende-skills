# Fixing IdentityServer Behind an Nginx Reverse Proxy

## The Problem

When IdentityServer is behind a reverse proxy (like nginx), the proxy terminates HTTPS and forwards requests as plain HTTP internally. The proxy strips the original scheme and host headers, causing IdentityServer to generate HTTP URLs in the discovery document (`/.well-known/openid-configuration`) instead of HTTPS. Cookies also lose their `Secure` attribute because IdentityServer sees the request as HTTP.

## Solution: Forwarded Headers Middleware

You need to configure ASP.NET Core to trust and process the forwarded headers from nginx.

### Option 1: Explicit Configuration (Recommended for Production)

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                                ForwardedHeaders.XForwardedProto;

    // If you know the proxy IP, add it:
    // options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
    options.ForwardLimit = 1;
});

builder.Services.AddIdentityServer();

var app = builder.Build();

// UseForwardedHeaders MUST be early in the pipeline, before UseIdentityServer
app.UseForwardedHeaders();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

### Option 2: Environment Variable (Simpler for Cloud/Kubernetes)

Set the environment variable `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`. This is the simplest alternative for cloud or Kubernetes environments — ASP.NET Core will automatically configure forwarded headers middleware to trust all proxies:

```bash
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

### Nginx Configuration

Make sure your nginx config forwards the proper headers:

```nginx
location / {
    proxy_pass http://identityserver:5000;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## Why This Happens

The reverse proxy terminates TLS/HTTPS and forwards requests to IdentityServer over plain HTTP. Without forwarded headers:

1. IdentityServer sees `http://` as the request scheme
2. The discovery document uses `http://` for all endpoint URLs
3. Authentication cookies are not marked as `Secure` (because the request appears to be HTTP)
4. Token issuers may not match what clients expect
