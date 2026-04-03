Here's how to configure IdentityServer behind a reverse proxy with the various options:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://id.mycompany.com";

    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Enable caching
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

This sets the issuer URI for the reverse proxy, configures the cookie lifetime to 8 hours without sliding, and enables caching with 10-minute expiration. For PAR (Pushed Authorization Requests), you would need to check the specific configuration options available in your version of IdentityServer.
