# Production IdentityServer Configuration Behind Nginx

Here's the complete configuration with IssuerUri, authentication cookies, PAR, and caching:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // External URL behind reverse proxy
    options.IssuerUri = "https://id.mycompany.com";

    // Authentication cookie settings
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Require Pushed Authorization Requests for all clients
    options.PushedAuthorization.Required = true;

    // Store caching
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);

    // Events for monitoring
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
});

// Enable caching for stores
idsvrBuilder.AddInMemoryCaching();
```

## Configuration Details

### IssuerUri

`options.IssuerUri = "https://id.mycompany.com"` sets the issuer claim (`iss`) in all tokens. Behind a reverse proxy, IdentityServer's internal URL differs from the external URL clients see. Without this, the `iss` claim would contain the internal hostname, causing token validation failures.

### Authentication Cookie

- `CookieLifetime = TimeSpan.FromHours(8)` — The user's session lasts 8 hours.
- `CookieSlidingExpiration = false` — The cookie expires at a fixed time, not extended by activity. This is more predictable for security policies.

### Pushed Authorization Requests (PAR)

`PushedAuthorization.Required = true` forces all clients to use PAR. Instead of sending authorization parameters in the URL query string, clients first POST them to the PAR endpoint and receive a request URI. This prevents:
- Authorization parameter tampering
- URL length limitations
- Sensitive parameter leakage in browser history or logs

### Caching

`ClientStoreExpiration` and `ResourceStoreExpiration` at 10 minutes reduce database queries for client and resource lookups. Requires calling `AddInMemoryCaching()` on the builder (or a custom `ICache<T>` implementation).
