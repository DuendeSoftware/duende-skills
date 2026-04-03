# Fix Discovery Document Showing HTTP URLs Behind Nginx

## Problem

When your IdentityServer runs behind Nginx that terminates TLS, the app sees HTTP requests internally. The discovery document then generates HTTP URLs.

## Solution

You need to configure ASP.NET Core's forwarded headers middleware to trust the proxy headers.

Update your `Program.cs`:

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

## Explanation

- `ForwardedHeaders.XForwardedProto` tells ASP.NET Core to read the `X-Forwarded-Proto` header from Nginx, which will be set to `https`.
- The `UseForwardedHeaders()` middleware should be early in the pipeline so the correct scheme is available to subsequent middleware.
- Make sure Nginx is setting the `X-Forwarded-Proto` header in its configuration.
