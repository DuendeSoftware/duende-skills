```csharp
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    o.KnownNetworks.Clear(); o.KnownProxies.Clear(); // restrict in production
});

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://id.mycompany.com";
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
    options.Endpoints.EnablePushedAuthorizationEndpoint = true;
    options.PushedAuthorization.Required = true;
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
.AddInMemoryCaching()
.AddClientStoreCache<IdentityServer4.Stores.IClientStore>(); // see note

var app = builder.Build();
app.UseForwardedHeaders();
app.UseIdentityServer();
```
Call `UseForwardedHeaders` first. Caching only applies to non-in-memory stores: add `.AddClientStoreCache<YourClientStore>()` and `.AddResourceStoreCache<YourResourceStore>()` after `AddInMemoryCaching()`. Nginx must forward `X-Forwarded-Proto`/`Host`. Usually you can omit IssuerUri and let forwarded headers infer it.
