# Token Caching with Redis for Duende.AccessTokenManagement

To cache tokens in Redis with a custom lifetime buffer and encryption, you can configure the distributed cache and set up encryption.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register Redis as distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// Configure token management with cache buffer
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

builder.Services.AddClientCredentialsHttpClient("api", "api.client",
    client => { client.BaseAddress = new Uri("https://api.example.com/"); });

// Add data protection for encryption
builder.Services.AddDataProtection();

var app = builder.Build();
app.Run();
```

## Encrypting Cached Tokens

To encrypt tokens stored in Redis, you could create a custom `IDistributedCache` wrapper that encrypts values before storing them:

```csharp
public class EncryptedDistributedCache : IDistributedCache
{
    private readonly IDistributedCache _inner;
    private readonly IDataProtector _protector;

    public EncryptedDistributedCache(
        IDistributedCache inner,
        IDataProtectionProvider provider)
    {
        _inner = inner;
        _protector = provider.CreateProtector("TokenCache");
    }

    public byte[]? Get(string key)
    {
        var encrypted = _inner.Get(key);
        return encrypted != null ? _protector.Unprotect(encrypted) : null;
    }

    public async Task<byte[]?> GetAsync(string key, CancellationToken token = default)
    {
        var encrypted = await _inner.GetAsync(key, token);
        return encrypted != null ? _protector.Unprotect(encrypted) : null;
    }

    public void Set(string key, byte[] value, DistributedCacheEntryOptions options)
    {
        _inner.Set(key, _protector.Protect(value), options);
    }

    public Task SetAsync(string key, byte[] value, DistributedCacheEntryOptions options,
        CancellationToken token = default)
    {
        return _inner.SetAsync(key, _protector.Protect(value), options, token);
    }

    // ... other IDistributedCache methods
}
```

## Explanation

- Redis provides distributed caching so tokens are shared across multiple instances of your application.
- The `CacheLifetimeBuffer` of 120 seconds ensures tokens are refreshed before they expire.
- The encrypted cache wrapper protects tokens at rest in the shared Redis instance.
- Data Protection handles the encryption/decryption.
