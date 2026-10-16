# Cloudflare → Nginx → IdentityServer

The likely issue: `ForwardLimit` defaults to 1, and `KnownProxies`/`KnownNetworks` only trust localhost (`127.0.0.1/8`, `::1`). With two proxies, only one hop is processed and/or the proxies' addresses aren't trusted, so the forwarded headers are ignored or only partially applied.

Fix: set `ForwardLimit` to the number of proxies and add **all** proxy addresses to `KnownProxies`/`KnownNetworks`; run the middleware early.

```csharp
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedHost |
                               ForwardedHeaders.XForwardedProto;

    options.ForwardLimit = 2;   // Cloudflare + Nginx

    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));   // Nginx
    // Cloudflare ranges (the address of the previous hop is validated per hop):
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20));
    // ...add the remaining Cloudflare ranges
});

var app = builder.Build();
app.UseForwardedHeaders();   // before UseIdentityServer and authentication
app.UseIdentityServer();
```

Also check:
- Nginx must forward/append, not overwrite, the headers (`X-Forwarded-For $proxy_add_x_forwarded_for`; pass through upstream `X-Forwarded-Proto`/`Host`, since `$scheme` between Cloudflare and Nginx may be `http`).
- Cloudflare sends `X-Forwarded-Proto` but not `X-Forwarded-Host`; keep `Host` consistent.
- `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` handles only a single proxy, so it isn't enough here.
- Verify `issuer` in `/.well-known/openid-configuration` is the public https host.
