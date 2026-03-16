# Fixing Transport Security Behind AWS ALB

The core issue is that your AWS ALB terminates TLS, so IdentityServer receives HTTP requests and publishes an `http://` issuer in the discovery document. You need `ForwardedHeaders` middleware to restore the original scheme, plus HTTPS redirection and strong HSTS.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;
using Serilog;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Configure ForwardedHeaders — required behind ALB/reverse proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    // Restrict to known proxy IP — never accept forwarded headers from any source
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
    options.ForwardLimit = 1;
});

// Strong HSTS configuration
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

// Force HTTPS redirect with 308 Permanent Redirect
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
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
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders"),
        new ApiScope("internal-api", "Internal API access")
    })
    .AddInMemoryClients(new List<Client>
    {
        // ... clients omitted for brevity
    });

builder.Services.AddRazorPages();

var app = builder.Build();

// 1. ForwardedHeaders MUST be the very first middleware
app.UseForwardedHeaders();

// 2. HTTPS redirection — permanent redirect (308) for any HTTP request
app.UseHttpsRedirection();

// 3. HSTS — tell browsers to always use HTTPS
app.UseHsts();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## What Changed

1. **ForwardedHeaders middleware** — Configured with `XForwardedFor | XForwardedProto`, restricted to `KnownProxies` with only `10.0.0.1` (the ALB IP). This ensures IdentityServer sees the original `https://` scheme.

2. **HSTS** — Configured with `MaxAge = 365 days`, `IncludeSubDomains = true`, and `Preload = true` for browser preload list eligibility.

3. **HTTPS Redirection** — Uses `StatusCodes.Status308PermanentRedirect` (308) to permanently redirect any HTTP request.

4. **Middleware ordering** — `UseForwardedHeaders()` → `UseHttpsRedirection()` → `UseHsts()` → `UseIdentityServer()`. ForwardedHeaders must be first so subsequent middleware sees the correct scheme.

Without `ForwardedHeaders`, IdentityServer publishes an `http://` issuer URI in the discovery document, causing `IDX20803` token validation failures in every downstream API.
