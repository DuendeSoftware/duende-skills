# Fixing ForwardedHeaders with Two Proxies (Cloudflare -> Nginx -> IdentityServer)

## Problem

Your ForwardedHeaders configuration is likely only set up for a single proxy. When you have two proxies in the chain, you need to account for both.

## Solution

Update your ForwardedHeaders configuration:

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto |
                                ForwardedHeaders.XForwardedHost;

    // Add both proxy IPs
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.5"));     // Nginx IP
    options.KnownProxies.Add(IPAddress.Parse("172.16.0.100")); // Cloudflare IP
    
    // Or use network ranges for Cloudflare
    options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("173.245.48.0"), 20));
});

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();
```

## Key Points

1. **Include XForwardedHost** — Since the discovery document shows the wrong host, you need to include `ForwardedHeaders.XForwardedHost` to correct the hostname, not just the scheme.

2. **Trust both proxies** — Both Cloudflare and Nginx need to be in `KnownProxies` or `KnownNetworks`. The middleware only processes headers from trusted sources. Each proxy in the chain must be trusted for the headers to be fully processed through the chain.

3. **Proxy header chain** — With two proxies, each one appends to the X-Forwarded headers. Make sure both are sending the correct headers.

4. **Nginx configuration** — Ensure Nginx is passing through the forwarded headers from Cloudflare:

```nginx
location / {
    proxy_pass http://identityserver:5000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
}
```

After these changes, verify the discovery document shows the correct URLs with the proper host and https scheme.
