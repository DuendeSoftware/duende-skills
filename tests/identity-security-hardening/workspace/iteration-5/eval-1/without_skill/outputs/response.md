# Fixing Transport Security Behind a Reverse Proxy

The `http://` issuer in your discovery document is happening because your app is behind the AWS ALB which terminates TLS. The request that reaches your app is plain HTTP, so ASP.NET Core thinks the scheme is `http`. You need to enable forwarded headers so the app honors `X-Forwarded-Proto`. Then add HTTPS redirection and HSTS.

## Updated `Program.cs`

Register the options before building the app:

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // Only trust the ALB
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

builder.Services.AddHsts(options =>
{
    options.Preload = true;
    options.IncludeSubDomains = true;
    options.MaxAge = TimeSpan.FromDays(365);
});

builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});
```

Then configure the pipeline. The forwarded-headers middleware has to run first, before anything that looks at the scheme:

```csharp
var app = builder.Build();

app.UseForwardedHeaders();   // must be first
app.UseHttpsRedirection();
app.UseHsts();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();
app.Run();
```

## Notes

- **Forwarded headers must come first** so IdentityServer computes the issuer with the `https` scheme. That fixes the `IDX20803` errors your APIs are getting.
- Restricting `KnownProxies` to `10.0.0.1` means only your ALB can set the forwarded headers, which prevents spoofing.
- HSTS is set to one year with subdomains and preload, which is the recommended strong configuration.
- The 308 status code makes the HTTP→HTTPS redirect a permanent redirect that preserves the request method.

One thing to double-check: in production behind a load balancer, ASP.NET Core seeds `KnownNetworks`/`KnownProxies` with loopback entries by default. If your setup needs strictly only the ALB, you may want to clear those first. Also make sure your ALB is actually forwarding the `X-Forwarded-Proto` header.
