# IdentityServer Behind an Nginx Reverse Proxy

This configures the external issuer, an 8-hour non-sliding auth cookie, mandatory PAR for all clients, and 10-minute store caching.

```csharp
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // External issuer as seen by clients (behind Nginx at id.mycompany.com)
    options.IssuerUri = "https://id.mycompany.com";

    // Authentication cookie: 8 hours, fixed (no sliding renewal)
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Require Pushed Authorization Requests for every client
    options.PushedAuthorization.Required = true;

    // Cache client and resource store lookups for 10 minutes
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    // Store caching must be turned on for the Caching.* expirations to apply:
    .AddInMemoryCaching()
    .AddClientStoreCache<Duende.IdentityServer.Stores.IClientStore>()
    .AddResourceStoreCache<Duende.IdentityServer.Stores.IResourceStore>();

var app = builder.Build();

// Honor X-Forwarded-* headers from Nginx so scheme/host are correct
app.UseForwardedHeaders(new Microsoft.AspNetCore.Builder.ForwardedHeadersOptions
{
    ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor
                     | Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto
});

app.UseIdentityServer();
app.Run();
```

## Notes

- **`IssuerUri = "https://id.mycompany.com"`** — set explicitly because, behind Nginx, the request host IdentityServer sees is the internal one. Without this, tokens would carry an internal `iss` value that clients reject. Also forward the proto/host headers from Nginx (shown above) so redirect URLs and discovery are correct.
- **`Authentication.CookieLifetime = 8 hours` + `CookieSlidingExpiration = false`** — these are IdentityServer's own authentication cookie settings (not the generic ASP.NET cookie options). A fixed lifetime means the session expires 8 hours after login regardless of activity.
- **`PushedAuthorization.Required = true`** — forces all clients to use PAR (RFC 9126); authorization parameters must be pushed to the PAR endpoint first.
- **`Caching.ClientStoreExpiration` / `ResourceStoreExpiration = 10 minutes`** — cache durations for the client and resource stores. These only take effect when store caching is enabled (`AddInMemoryCaching()` plus the `AddClientStoreCache`/`AddResourceStoreCache` registrations).
