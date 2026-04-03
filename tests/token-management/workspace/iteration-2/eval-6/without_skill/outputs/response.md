# Token Caching with Redis and Encryption

Here's how to set up Redis-based token caching with Duende.AccessTokenManagement and encrypt the cached tokens.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Register Redis as the distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// Register Data Protection
builder.Services.AddDataProtection();

// Register client credentials token management
builder.Services.AddDistributedMemoryCache(); // fallback for local dev
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120;
})
.AddClient("api.client", client =>
{
    client.TokenEndpoint = "https://sts.example.com/connect/token";
    client.ClientId = "my-service";
    client.ClientSecret = "my-secret";
    client.Scope = "api1";
});

builder.Services.AddHttpClient("api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/");
}).AddClientCredentialsTokenHandler("api.client");

var app = builder.Build();
app.Run();
```

## Notes

- `AddStackExchangeRedisCache` configures Redis as the backing store for token caching.
- `CacheLifetimeBuffer = 120` tells the library to refresh tokens 120 seconds before they expire.
- `AddDataProtection()` is registered but the actual token encryption would need a custom implementation to intercept the cache writes — the library stores tokens in its distributed cache, and you would need to wrap the `IDistributedCache` with encryption logic.
- Consider implementing a custom `IDistributedCache` decorator that encrypts/decrypts values using Data Protection.
