# Fixing HTTP URLs in Discovery Document Behind Nginx

## Problem

When your IdentityServer sits behind Nginx with TLS termination, the app only sees the internal HTTP request. The discovery document then generates `http://` URLs. You need to configure ASP.NET Core to read the forwarded headers from Nginx.

## Solution

Configure the `ForwardedHeaders` middleware in your `Program.cs`:

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto;

    // In production, add your proxy's IP address
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// Must be called before other middleware
app.UseForwardedHeaders();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Important Notes

1. **Middleware order matters** — `UseForwardedHeaders()` must be called before `UseIdentityServer()` so the scheme is corrected before IdentityServer generates its URLs.

2. **KnownProxies** — By default, only loopback addresses are trusted. For production deployments, you should add your Nginx server's IP address to `KnownProxies`, or add the subnet to `KnownNetworks`. Without this, the middleware won't process headers from unknown proxies.

3. **XForwardedProto** — This is the key header. Nginx sets `X-Forwarded-Proto: https` when it terminates TLS. The middleware uses it to set `Request.Scheme` to `https`.

Alternatively, you can set the environment variable `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` which enables ForwardedHeaders middleware automatically.

## Nginx Configuration

Make sure your Nginx config passes the necessary headers:

```nginx
location / {
    proxy_pass http://localhost:5000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;
}
```
