# HTTP URLs and Missing Secure Cookies Behind an nginx Reverse Proxy

## Root cause

nginx is terminating TLS and forwarding the request to your ASP.NET Core app over internal HTTP. As a result the app sees `scheme = http` and an internal host, not the public `https://` host the browser used. The reverse proxy has effectively **stripped the original scheme and host**, so:

- IdentityServer generates `http://` URLs in the discovery document and redirects (it derives them from the request it sees).
- ASP.NET Core doesn't mark cookies with the `Secure` attribute because it thinks the connection is plain HTTP.

nginx passes the real values in `X-Forwarded-Proto` (the original `https`) and `X-Forwarded-Host`. You need ASP.NET Core to apply them.

## Fix: Forwarded Headers Middleware

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto |
        ForwardedHeaders.XForwardedHost;
});

var app = builder.Build();

// Apply forwarded headers before anything that reads scheme/host.
app.UseForwardedHeaders();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

`ForwardedHeaders.XForwardedProto` is the important flag here — it restores `https` as the request scheme, which fixes both the `http://` discovery URLs and the missing `Secure` cookie attribute. Call `UseForwardedHeaders()` **early**, before `UseIdentityServer()`.

## Simpler alternative

You can enable the same processing without code by setting the environment variable:

```
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```

This is handy for containerized/Kubernetes deployments.

## nginx side

Make sure nginx actually forwards the headers:

```nginx
proxy_set_header Host              $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host  $host;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
```

For production, also configure `KnownProxies`/`KnownNetworks` on `ForwardedHeadersOptions` so the headers are only trusted from your proxy.
