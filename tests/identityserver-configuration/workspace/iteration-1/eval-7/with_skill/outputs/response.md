Here's the configuration for deploying IdentityServer behind Nginx with the specified settings:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Set the issuer to the external URL behind the reverse proxy
    options.IssuerUri = "https://id.mycompany.com";

    // Events for monitoring
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;

    // Authentication cookie: 8 hours, no sliding expiration
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Require Pushed Authorization Requests (PAR) for all clients
    options.PushedAuthorization.Required = true;

    // Cache client and resource store lookups for 10 minutes
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Explanation of Each Setting

1. **`IssuerUri = "https://id.mycompany.com"`** — When IdentityServer is behind a reverse proxy, the internal hostname/port doesn't match the external URL. Without this setting, tokens would contain an `iss` claim with the internal address, and clients would reject them. Setting `IssuerUri` ensures all tokens and discovery responses use the correct external URL.

2. **`CookieLifetime = TimeSpan.FromHours(8)` and `CookieSlidingExpiration = false`** — The authentication cookie expires after exactly 8 hours regardless of user activity. With `CookieSlidingExpiration = false`, the cookie won't be renewed on each request — once 8 hours pass from login, the user must re-authenticate. This is a common enterprise requirement.

3. **`PushedAuthorization.Required = true`** — Requires all clients to use Pushed Authorization Requests (PAR, RFC 9126). With PAR, clients send authorization parameters directly to the PAR endpoint first and receive a `request_uri` reference. The browser redirect to the authorize endpoint only contains this reference, not the actual parameters. This prevents:
   - Authorization parameter tampering in the browser
   - Large authorization requests exceeding URL length limits
   - Exposure of sensitive parameters in browser history/logs

4. **`Caching.ClientStoreExpiration` and `Caching.ResourceStoreExpiration`** — Caches client and resource lookups for 10 minutes. This reduces database round-trips when using EF Core or custom stores. The in-memory cache is invalidated after the expiration period.

### Nginx Configuration Note

Make sure your Nginx configuration forwards the correct headers so ASP.NET Core can determine the original scheme and host:

```nginx
location / {
    proxy_pass http://localhost:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

And configure the forwarded headers middleware in your app:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

// Before UseIdentityServer()
app.UseForwardedHeaders();
```
