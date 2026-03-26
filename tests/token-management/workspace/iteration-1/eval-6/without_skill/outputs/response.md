# Redis Token Caching

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120;
})
.AddClient("api-client", client =>
{
    client.TokenEndpoint = "https://sts.example.com/connect/token";
    client.ClientId = "my-service";
    client.ClientSecret = "my-secret";
    client.Scope = "api1";
});
```

For encrypting tokens in the cache, you could implement a custom cache wrapper that uses Data Protection to encrypt/decrypt values before storing them in Redis.
