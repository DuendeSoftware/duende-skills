# Fix http:// URLs behind Nginx

IdentityServer builds its issuer and endpoint URLs from the incoming request. Nginx terminates TLS and forwards plain HTTP, so Kestrel sees `http`. Fix: have ASP.NET Core honor `X-Forwarded-Proto` / `X-Forwarded-Host` using the Forwarded Headers middleware, **before** `UseIdentityServer()`.

```csharp
using Microsoft.AspNetCore.HttpOverrides;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedProto |
                               ForwardedHeaders.XForwardedHost;
    // Trust only your proxy
    options.KnownProxies.Add(System.Net.IPAddress.Parse("10.0.0.5"));
    // or options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
});

var app = builder.Build();

app.UseForwardedHeaders();   // first in the pipeline
app.UseIdentityServer();
```

Nginx config:

```nginx
location / {
    proxy_pass http://identityserver:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
}
```

Notes:
- By default only loopback proxies are trusted, so if Nginx is on another IP/container, headers are ignored unless you add `KnownProxies`/`KnownNetworks`. Don't clear them in production (spoofing risk).
- Alternative: set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` (trusts all; fine only in locked-down networks such as containers).
- As a last resort you can set `options.IssuerUri` in `AddIdentityServer`, but this fixes only the issuer, not endpoint URLs, so prefer forwarded headers.
- Ensure cookies are `Secure` — they will be once the request scheme is https.
