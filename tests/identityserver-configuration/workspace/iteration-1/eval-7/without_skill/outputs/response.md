Here's how to configure IdentityServer for deployment behind Nginx:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Set issuer for reverse proxy
    options.IssuerUri = "https://id.mycompany.com";

    // Cookie settings
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This sets:
- The `IssuerUri` to match your external domain so tokens have the correct `iss` claim
- Cookie lifetime of 8 hours with no sliding expiration
- The middleware pipeline

For PAR (Pushed Authorization Requests), clients would need to send authorization requests to the PAR endpoint first. You can enforce this at the client level by setting `RequirePushedAuthorization = true` on individual client configurations.

For caching, you can add `IDistributedCache` and configure the caching middleware to reduce database lookups for client and resource stores.
