# Fixing Transport Security Behind AWS ALB

When your app is behind a load balancer that terminates TLS, ASP.NET Core sees HTTP requests. You need to configure forwarded headers so the app knows the original request was HTTPS.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Configure forwarded headers for reverse proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;
    // Clear the default networks/proxies restrictions to accept from any source
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

// Add HSTS
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(30);
    options.IncludeSubDomains = true;
});

// Add HTTPS redirection
builder.Services.AddHttpsRedirection(options =>
{
    options.HttpsPort = 443;
});

// IdentityServer registration
builder.Services.AddIdentityServer()
    .AddDeveloperSigningCredential()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read"),
        new ApiScope("catalog.write"),
        new ApiScope("orders.manage"),
        new ApiScope("internal-api")
    })
    .AddInMemoryClients(new List<Client>
    {
        // clients...
    });

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## Explanation

- `ForwardedHeaders` middleware reads the `X-Forwarded-For` and `X-Forwarded-Proto` headers from the ALB so the app knows requests were originally HTTPS.
- `UseHsts()` sends the `Strict-Transport-Security` header to browsers.
- `UseHttpsRedirection()` redirects HTTP requests to HTTPS.
- The middleware is placed before `UseIdentityServer()` so the correct scheme is used in the discovery document.
