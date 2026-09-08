# IdentityServer Behind an Nginx Reverse Proxy

Here's how to configure the external issuer, cookie lifetime, PAR, and store caching.

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // External URL clients will see as the token issuer
    options.IssuerUri = "https://id.mycompany.com";

    // Require Pushed Authorization Requests for all clients
    options.PushedAuthorization.Required = true;

    // Cache client and resource stores for 10 minutes
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryCaching()
    .AddClientStoreCache()
    .AddResourceStoreCache();

// Configure the authentication cookie: 8 hours, no sliding expiration
builder.Services.ConfigureApplicationCookie(options =>
{
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = false;
});

var app = builder.Build();

// Respect proxy headers from Nginx
app.UseForwardedHeaders();

app.UseIdentityServer();
app.Run();
```

## Notes

- **IssuerUri** is set to the public `https://id.mycompany.com` so the `iss` claim in issued tokens matches what clients expect. Behind a proxy you also want `UseForwardedHeaders()` so the scheme/host are respected.
- **Cookie lifetime**: set an 8-hour absolute expiration with `SlidingExpiration = false` on the application cookie.
- **PushedAuthorization.Required = true** forces every client through the PAR endpoint.
- **Caching**: `ClientStoreExpiration` and `ResourceStoreExpiration` set to 10 minutes, with store caching enabled via `AddInMemoryCaching()` and the cache registrations.
