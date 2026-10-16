# Two chained proxies and ForwardedHeaders

By default `ForwardedHeadersOptions.ForwardLimit` is **1**, so only the last proxy's entry in `X-Forwarded-*` is processed. With Cloudflare → Nginx → app, the headers contain two entries, and also `KnownProxies` defaults to loopback only, so headers from Nginx are ignored entirely if it's not trusted. Nginx may also overwrite `X-Forwarded-Proto`/`Host` with its own (`$scheme` = http between Cloudflare and Nginx).

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                         ForwardedHeaders.XForwardedProto |
                         ForwardedHeaders.XForwardedHost;
    o.ForwardLimit = 2;                     // or null to process all
    o.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));  // Nginx
    // Cloudflare ranges if Nginx isn't overriding
});

app.UseForwardedHeaders();  // before UseIdentityServer
app.UseIdentityServer();
```

Nginx should *pass through* the upstream values:
```nginx
map $http_x_forwarded_proto $fwd_proto { default $http_x_forwarded_proto; '' $scheme; }
proxy_set_header X-Forwarded-Proto $fwd_proto;
proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```
(Also `real_ip` module to trust Cloudflare IPs.) Note that Cloudflare doesn't send `X-Forwarded-Host`; it preserves `Host`, so Nginx should pass `Host $host`. Don't set `KnownNetworks` to Clear in production.
