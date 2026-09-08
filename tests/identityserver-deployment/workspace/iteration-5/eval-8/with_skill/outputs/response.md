# Two proxies in a chain (Cloudflare → Nginx → IdentityServer)

With a **chain** of proxies, the default ForwardedHeaders configuration only processes headers from **one** hop, and it only trusts loopback by default — so with Cloudflare → Nginx → IdentityServer the forwarded values get dropped or truncated and the discovery document still shows the wrong host.

Three things need to change: **`ForwardLimit`**, **trusting both proxies**, and including **`XForwardedHost`**.

## The fixes

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Fix the host as well as the scheme
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;

    // TWO proxies in front of the app (Cloudflare + Nginx), not the default 1
    options.ForwardLimit = 2;

    // Every proxy in the chain must be trusted, or its X-Forwarded-* values are ignored
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));   // Nginx (nearest hop)
    // Cloudflare egress ranges — add each network:
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20));
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("103.21.244.0"), 22));
    // ... add all Cloudflare IP ranges you receive traffic from
});
```

And register the middleware **before** IdentityServer:

```csharp
app.UseForwardedHeaders();
app.UseIdentityServer();
```

## Why each change matters

1. **`ForwardLimit = 2`** — The default is **1**, meaning the middleware only processes the headers contributed by a **single** proxy and stops. With two proxies in the chain, it must be set to `2` (match the number of proxies) so it walks back through both entries in `X-Forwarded-For`/`X-Forwarded-Proto`/`X-Forwarded-Host` to reach the original client values. Left at 1, you only "peel" the nearest proxy and still see Nginx's view, not the original request.

2. **Trust *every* proxy in the chain** — ASP.NET Core only accepts forwarded headers when the immediate sender is a **known** proxy/network. By default only localhost is trusted. You must add **both** Nginx and the Cloudflare egress ranges to `KnownProxies`/`KnownNetworks`; otherwise the middleware treats the headers as untrusted and drops them, and the host/scheme revert to the internal values.

3. **`XForwardedHost`** — Your specific symptom is the **wrong host** in the discovery document. `XForwardedProto` alone only fixes http→https; you also need `ForwardedHeaders.XForwardedHost` so ASP.NET Core rewrites `Request.Host` from the `X-Forwarded-Host` header. That's what makes the issuer/host in `/.well-known/openid-configuration` correct.

## Verify

After deploying, request `/.well-known/openid-configuration` through Cloudflare and confirm the `issuer` shows the public HTTPS host, not the internal Nginx/Kestrel host.
