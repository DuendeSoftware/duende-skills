# Fixing HTTP issuer URLs behind an Nginx TLS-terminating proxy

## What's happening

When IdentityServer runs behind Nginx that terminates TLS, ASP.NET Core sees the request as plain HTTP on the internal hop (Nginx → Kestrel). IdentityServer builds the issuer and all URLs in `/.well-known/openid-configuration` from the current request scheme/host, so it publishes `http://` instead of `https://`.

The fix is to make ASP.NET Core honor the `X-Forwarded-Proto` (and `X-Forwarded-Host`) headers that Nginx sends, using the **ForwardedHeaders middleware**. This must run **early**, before `UseIdentityServer()`.

## Option 1 — Environment variable (simplest)

Set:

```
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

This automatically registers the ForwardedHeaders middleware and accepts `X-Forwarded-For`/`X-Forwarded-Proto` from a single proxy. It's the least-effort option and works well for containers/Kubernetes.

## Option 2 — Explicit configuration (more control)

In your `Program.cs`:

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // Trust your Nginx proxy. In production add its real address, not just localhost.
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5")); // Nginx IP
    // or a range:
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 24));

    options.ForwardLimit = 1; // one proxy in front of the app
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// MUST run before UseIdentityServer so IdentityServer sees the corrected scheme/host
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Why the middleware order matters

The ForwardedHeaders middleware rewrites `HttpContext.Request.Scheme` (to `https`) and `Host` **before** IdentityServer processes the request. If it runs after `UseIdentityServer()`, the discovery document is generated from the un-corrected HTTP scheme and you still get `http://` issuer URLs.

## KnownProxies / KnownNetworks in production

By default, `KnownNetworks` and `KnownProxies` only trust localhost (`127.0.0.1/8` and `::1`). That's fine when Nginx and Kestrel share a host, but for a real deployment the forwarded headers are **ignored unless the immediate sender is trusted**. Add your Nginx address(es):

- `options.KnownProxies.Add(IPAddress.Parse("<nginx-ip>"))`, or
- `options.KnownNetworks.Add(new IPNetwork(...))` for a range.

If you don't add the proxy, ASP.NET Core silently drops the `X-Forwarded-*` headers as a security precaution and the issuer stays HTTP.

## Verify

After deploying, request `/.well-known/openid-configuration` and confirm `issuer`, `jwks_uri`, `token_endpoint`, etc. all show `https://`. As a bonus, cookies will now correctly get the `Secure` attribute, which fixes `SameSite=None` behavior behind the proxy.
