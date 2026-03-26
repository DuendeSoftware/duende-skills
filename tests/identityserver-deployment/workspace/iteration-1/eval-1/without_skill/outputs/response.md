# Fixing HTTP URLs in Discovery Document

When running behind Nginx that terminates TLS, you need to configure forwarded headers so ASP.NET Core knows the original request was HTTPS.

## Solution

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto;
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

Make sure your Nginx configuration sets:
```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

This should fix the HTTP URLs in the discovery document.
