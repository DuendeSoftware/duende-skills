# Fixing ForwardedHeaders for a Cloudflare → Nginx → IdentityServer chain

The problem is that ASP.NET Core's Forwarded Headers middleware, by default, is tuned for a **single** trusted proxy. With two proxies in front of your app (Cloudflare and Nginx), the defaults cause it to either stop after one hop or ignore the headers entirely, so `Request.Host` never gets corrected and the discovery document shows the wrong host.

## What to change

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto |
        ForwardedHeaders.XForwardedHost;   // needed to fix the wrong host

    // Two proxies in the chain, so process two forwarded entries
    options.ForwardLimit = 2;

    // Trust BOTH proxies — Nginx and Cloudflare's ranges
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5")); // Nginx
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20)); // Cloudflare
    // add the rest of Cloudflare's published IP ranges
});
```

Register it early, before IdentityServer:

```csharp
app.UseForwardedHeaders();
app.UseIdentityServer();
```

## Why

1. **`ForwardLimit`** defaults to **1**. That processes only the closest proxy's forwarded values. With a two-proxy chain you must set `ForwardLimit = 2` so the middleware walks back through both entries in the `X-Forwarded-*` headers to reach the original client/host values. This is the most common reason a multi-proxy setup "doesn't work."

2. **Trust each proxy.** The middleware only honors forwarded headers when the immediate sender is in `KnownProxies` or `KnownNetworks` (default is loopback only). Both Nginx **and** Cloudflare's egress ranges must be added; if any hop in the chain is untrusted, the headers are discarded and the host/scheme fall back to the internal values.

3. **Add `XForwardedHost`.** Your symptom is the wrong host specifically. `XForwardedProto` fixes only the scheme; including `ForwardedHeaders.XForwardedHost` makes ASP.NET Core rewrite `Request.Host` from `X-Forwarded-Host`, which is what corrects the host in the discovery document.

## A note on Cloudflare

Cloudflare sends the original host in the `Host` header and the client IP in `CF-Connecting-IP` / `X-Forwarded-For`. Make sure Nginx forwards the host through (`proxy_set_header Host $host;` and `X-Forwarded-Host`) so the value actually reaches your app. Keep Cloudflare's IP ranges up to date in `KnownNetworks`.

## Verify

Request `/.well-known/openid-configuration` through the public Cloudflare hostname and confirm the `issuer` and endpoints show the correct public host over HTTPS.
