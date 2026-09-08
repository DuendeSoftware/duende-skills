# Fixing HTTP URLs in the OpenID discovery document behind Nginx

## Root cause

Your Nginx proxy terminates TLS, so the connection between Nginx and your app (Kestrel) is plain HTTP. ASP.NET Core builds absolute URLs — including the `issuer` and endpoint URLs in `/.well-known/openid-configuration` — from `Request.Scheme` and `Request.Host`. Since it sees `http` on the internal hop, it publishes `http://` URLs.

The fix is to tell ASP.NET Core to trust the `X-Forwarded-Proto` and `X-Forwarded-Host` headers Nginx sends, using **Forwarded Headers middleware**.

## Program.cs configuration

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // Trust your Nginx host. Without this the headers are dropped.
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// IMPORTANT: run this first, before other middleware
app.UseForwardedHeaders();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

The key point is that `UseForwardedHeaders()` must be registered **early in the pipeline, before IdentityServer** (and before authentication). It rewrites `Request.Scheme` to `https`, so by the time IdentityServer generates the discovery document it produces the correct HTTPS URLs.

## Alternative: environment variable

You can skip the code and just set:

```
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

This registers the middleware automatically and accepts forwarded headers from a single proxy — handy for containerized deployments.

## Trusting the proxy (production note)

By default ASP.NET Core only trusts forwarded headers from loopback (`127.0.0.1`/`::1`). In production you must add your actual Nginx IP(s) to `KnownProxies`, or the network range to `KnownNetworks`, otherwise the `X-Forwarded-*` headers are silently ignored and you'll still see `http://`.

Also make sure Nginx actually forwards the headers:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

## Verify

Hit `/.well-known/openid-configuration` and confirm the `issuer` and endpoints are now `https://`.
