# Fixing transport security behind the AWS ALB

The ALB terminates TLS and forwards plain HTTP, so Kestrel sees `http` and IdentityServer builds an `http://` issuer. The fix is to process the `X-Forwarded-*` headers from your trusted proxy, then add HTTPS redirection and HSTS.

```csharp
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // Only trust the known proxy
    options.KnownProxies.Clear();
    options.KnownNetworks.Clear();
    var proxy = builder.Configuration["ReverseProxy:ProxyAddress"]!; // 10.0.0.1
    options.KnownProxies.Add(IPAddress.Parse(proxy));
    options.ForwardLimit = 1;
});

builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

builder.Services.AddHttpsRedirection(o => o.HttpsPort = 443);

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = builder.Configuration["IdentityServer:IssuerUri"]; // https://identity.example.com
})
// ... existing config
;

var app = builder.Build();

// Must be first
app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}
app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```

## Notes
- **Order matters**: `UseForwardedHeaders` must run before HSTS, redirection and IdentityServer, otherwise the scheme is still `http`.
- **Trust only 10.0.0.1**: clearing `KnownNetworks`/`KnownProxies` and adding only your proxy prevents clients from spoofing `X-Forwarded-Proto`/`X-Forwarded-For`. Note that an ALB has multiple, changing IPs, so in practice you'll likely need to add the ALB's subnet CIDR (`KnownNetworks.Add(new IPNetwork(...))`) rather than a single IP.
- **HSTS**: 1 year, includeSubDomains, preload. Only enable preload when every subdomain really is HTTPS-only. HSTS is ignored on localhost and is intentionally disabled in Development.
- Setting `IssuerUri` explicitly also pins the discovery issuer to `https://`, a useful safety net, although with correct forwarded headers it's often unnecessary (omitting it lets the issuer derive from the request).
- Make sure the ALB sets `X-Forwarded-Proto` (it does by default) and that the ALB listener on 80 redirects to 443.
- Because the ALB forwards HTTP, `UseHttpsRedirection` only works properly because of forwarded headers; otherwise you'd get an infinite redirect loop.
