# Forwarded Headers with Multiple Proxies

## Problem

When you have multiple proxies in a chain, the forwarded headers configuration might need adjusting. The issue is likely that the middleware isn't processing headers from all proxies.

## Solution

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;
    
    // Clear defaults and add your proxy
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5")); // Nginx IP
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();

app.Run();
```

Make sure your Nginx is correctly forwarding the `X-Forwarded-Host` and `X-Forwarded-Proto` headers from Cloudflare. Each proxy in the chain should preserve and forward these headers.
