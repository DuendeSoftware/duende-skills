Here's the complete `Program.cs` with all the requested configuration:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Set IssuerUri for reverse proxy deployment
    options.IssuerUri = "https://id.mycompany.com";

    // Authentication cookie settings
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Require Pushed Authorization Requests (PAR) for all clients
    options.PushedAuthorization.Required = true;

    // Caching for client and resource stores
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);

    // Enable events for diagnostics
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Explanation:**

1. **`options.IssuerUri = "https://id.mycompany.com"`** — When deployed behind a reverse proxy (Nginx), the `iss` claim in tokens would default to the internal hostname. Setting `IssuerUri` explicitly ensures all tokens use the external URL that clients expect.

2. **`options.Authentication.CookieLifetime = TimeSpan.FromHours(8)`** — Sets the authentication session cookie to expire after 8 hours.

3. **`options.Authentication.CookieSlidingExpiration = false`** — Disables sliding expiration so the cookie lifetime is absolute (not extended by user activity).

4. **`options.PushedAuthorization.Required = true`** — Requires all clients to use Pushed Authorization Requests (PAR). PAR improves security by sending the authorization request directly to IdentityServer before the browser redirect, so the parameters cannot be tampered with.

5. **`options.Caching.ClientStoreExpiration` and `options.Caching.ResourceStoreExpiration`** — Both set to 10 minutes. This caches client and resource store lookups to reduce database calls. The caching feature works with `AddConfigurationStoreCache()` when using EF Core stores.
