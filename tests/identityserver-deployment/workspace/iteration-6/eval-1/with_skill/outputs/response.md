# Discovery shows http:// behind Nginx

IdentityServer derives its issuer and endpoint URLs from the request it sees. Nginx terminates TLS and forwards HTTP, so the app thinks it's HTTP. The fix is the ForwardedHeaders middleware, which must run **early, before `UseIdentityServer()`** and authentication.

## Option 1: environment variable (simplest)
`ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` adds the middleware and accepts headers from a single proxy.

## Option 2: explicit configuration in Program.cs

```csharp
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                               ForwardedHeaders.XForwardedProto;

    // Your Nginx address (defaults trust only localhost 127.0.0.1/8 and ::1)
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42"));
    // or a range:
    // options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("198.51.100.0"), 24));

    options.ForwardLimit = 1;   // one proxy
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseForwardedHeaders();   // BEFORE IdentityServer / authentication
app.UseIdentityServer();
```

Nginx must send the headers:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

## Why it matters / checks
- Without it you get an `http` issuer in discovery, wrong hosts in redirects, and cookies missing `Secure` (breaking `SameSite=None` flows).
- If Nginx isn't on localhost and isn't in `KnownProxies`/`KnownNetworks`, headers are silently ignored.
- Verify by opening `/.well-known/openid-configuration` and checking `issuer` is `https://...`.
- With more than one proxy, set `ForwardLimit` to the number of proxies and list all of them.
