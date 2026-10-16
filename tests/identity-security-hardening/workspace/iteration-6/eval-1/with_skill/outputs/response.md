# Transport security behind the ALB

**Root cause:** the ALB terminates TLS and forwards plain HTTP, so IdentityServer sees scheme `http` and publishes an `http://` issuer in discovery. Downstream APIs then fail with `IDX20803`. The fix is `ForwardedHeaders` (restricted to your proxy), then HTTPS redirection and HSTS.

```csharp
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

// Forwarded headers: trust ONLY the known proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    options.KnownProxies.Add(IPAddress.Parse(builder.Configuration["ReverseProxy:ProxyAddress"] ?? "10.0.0.1"));
    options.ForwardLimit = 1;
});

// Strong HSTS (>= 1 year, includeSubDomains, preload)
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

// Permanent redirect, explicit port 443
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});

builder.Services.AddIdentityServer(options =>
{
    // Safety net: pin the issuer so discovery can never advertise http://
    options.IssuerUri = builder.Configuration["IdentityServer:IssuerUri"]; // https://identity.example.com
})
// ... existing resources/clients/signing
;

var app = builder.Build();

// Order matters: forwarded headers FIRST
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

## Why this works
- **`UseForwardedHeaders()` is the very first middleware.** Without it, `Request.Scheme` stays `http`, producing the `http://` issuer *and* an infinite redirect loop with `UseHttpsRedirection`.
- **`KnownProxies` = 10.0.0.1 only.** If it were empty or too broad, anyone could spoof `X-Forwarded-Proto: https`/`X-Forwarded-For`. `ForwardLimit = 1` accepts one proxy hop. The address is read from the existing `ReverseProxy:ProxyAddress` setting. (ALB nodes can use several IPs; if your ALB isn't a single address, add its subnet to `KnownNetworks` instead of opening up trust.)
- **HSTS**: 365 days with `IncludeSubDomains` and `Preload` is the minimum bar. Only submit for preload when all subdomains are HTTPS. Note ASP.NET Core skips HSTS on localhost by default.
- **`IssuerUri`** already exists in `appsettings.json` and acts as defense in depth.
- If Kestrel were exposed directly (no proxy), also set `SslProtocols = Tls12 | Tls13` through `ConfigureHttpsDefaults`. Behind the ALB, TLS policy is configured on the ALB listener (choose a TLS 1.2+ security policy).

Make sure the ALB listener on port 80 redirects to 443 and that it passes `X-Forwarded-Proto` (the default).
