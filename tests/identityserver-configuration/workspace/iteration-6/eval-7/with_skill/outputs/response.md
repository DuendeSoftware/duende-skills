```csharp
using Microsoft.AspNetCore.HttpOverrides;

builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    // restrict KnownProxies / KnownNetworks to your Nginx in production
});

builder.Services.AddIdentityServer(options =>
{
    // Behind a reverse proxy: set the external issuer (single-issuer deployments)
    options.IssuerUri = "https://id.mycompany.com";

    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    options.PushedAuthorization.Required = true;   // PAR required for all clients

    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
    .AddInMemoryCaching()
    .AddClientStoreCache<MyClientStore>()      // caching requires a non-in-memory store + cache decorator
    .AddResourceStoreCache<MyResourceStore>();

var app = builder.Build();
app.UseForwardedHeaders();   // before UseIdentityServer
app.UseIdentityServer();
app.UseAuthorization();
```
- Without it, the issuer defaults to the internal hostname (`http://internal-host:5000`) and clients reject tokens. Preferred is forwarding the public host via `ForwardedHeaders` (Nginx sends `X-Forwarded-Proto`/`X-Forwarded-Host`), or fixing `IssuerUri`. Don't set `IssuerUri` if you use Multi-Issuer/Spaces.
- Cookie: 8 h absolute, non-sliding.
- `PushedAuthorization.Required = true` makes all clients use PAR.
- Cache expirations apply only when store caching is enabled (`AddInMemoryCaching` + `Add*StoreCache<T>`), where `MyClientStore`/`MyResourceStore` are your (e.g. EF) stores.
