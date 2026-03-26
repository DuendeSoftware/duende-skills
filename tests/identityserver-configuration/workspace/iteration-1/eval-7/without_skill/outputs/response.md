# Production IdentityServer Configuration

Here's the configuration for deploying behind Nginx:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://id.mycompany.com";
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
});
```

Set the IssuerUri to the external URL so tokens have the correct issuer. Configure cookie lifetime to 8 hours with no sliding expiration. Enable caching for client and resource stores.

For Nginx, make sure to configure the `X-Forwarded-For` and `X-Forwarded-Proto` headers so IdentityServer correctly detects HTTPS.
