# IdentityServer Behind Nginx

## Problem

When behind a reverse proxy, IdentityServer sees HTTP instead of HTTPS, causing wrong URLs in the discovery document.

## Solution

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                                ForwardedHeaders.XForwardedProto;
});

builder.Services.AddIdentityServer();

var app = builder.Build();

app.UseForwardedHeaders();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

Configure Nginx to pass the forwarded headers and this should fix the HTTP/HTTPS issue.
