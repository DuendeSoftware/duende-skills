# Fixing IdentityServer Behind an Nginx Reverse Proxy

## The Problem

When your IdentityServer is behind a reverse proxy like nginx, the proxy handles HTTPS termination and forwards requests internally over HTTP. This means your application sees HTTP requests, so the discovery document and cookies reflect HTTP instead of HTTPS.

## Solution

You need to configure the forwarded headers middleware to restore the original scheme and host:

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto;
});

builder.Services.AddIdentityServer();

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();

app.Run();
```

## Nginx Config

Make sure nginx sends the proper headers:

```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Host $host;
```

The `ForwardedHeaders` middleware reads the `X-Forwarded-Proto` header and updates `HttpContext.Request.Scheme` accordingly. This fixes the discovery document URLs and cookie attributes.
