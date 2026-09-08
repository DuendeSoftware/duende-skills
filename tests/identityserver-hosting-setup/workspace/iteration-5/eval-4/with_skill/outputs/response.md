# Fixing HTTP URLs and Missing Secure Cookies Behind nginx

## Why this happens

When IdentityServer sits behind a reverse proxy like nginx, the proxy terminates TLS and forwards the request to your app over plain HTTP on an internal address. From your app's point of view the incoming request looks like `http://` on some internal host — the **original scheme (`https`) and host are stripped**.

IdentityServer infers the issuer, discovery document URLs, and redirect URLs from the current request. Because the request now appears to be HTTP, it generates `http://` URLs in the discovery document, and cookies are written without the `secure` attribute (ASP.NET Core only marks cookies secure when it believes the request is HTTPS).

nginx forwards the original values in the `X-Forwarded-Proto` and `X-Forwarded-Host` headers; you need to tell ASP.NET Core to honor them.

## Option 1: Environment variable (simplest — great for cloud/Kubernetes)

```
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

This enables the forwarded-headers processing without any code, and is the easiest option in containerized/Kubernetes deployments.

## Option 2: Explicit configuration (recommended for production)

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                               ForwardedHeaders.XForwardedProto;

    // Restrict to your known proxy so headers can't be spoofed by clients
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42"));
    options.ForwardLimit = 1;
});

var app = builder.Build();

// Must run EARLY, before UseIdentityServer(), so the scheme/host are
// corrected before IdentityServer reads them.
app.UseForwardedHeaders();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Key points

- `ForwardedHeaders.XForwardedProto` restores the original **`https`** scheme → fixes the `http://` URLs in discovery and makes cookies `secure`.
- `ForwardedHeaders.XForwardedHost` restores the original public host name → fixes incorrect host names in discovery/redirects.
- **`UseForwardedHeaders()` must be placed early in the pipeline, before `UseIdentityServer()`** (and before anything that reads scheme/host). Otherwise IdentityServer reads the un-corrected request.
- For security, set `KnownProxies`/`KnownNetworks` so only your trusted nginx can set these headers. The `ASPNETCORE_FORWARDEDHEADERS_ENABLED` env var is the simpler alternative when running in cloud/Kubernetes.
