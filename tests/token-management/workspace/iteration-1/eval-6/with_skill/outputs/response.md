# Token Caching with Redis and Data Protection Encryption

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register Redis as the distributed L2 cache tier
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// Register Data Protection for token encryption
builder.Services.AddDataProtection();

// Register the encrypted serializer
builder.Services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();

// Configure token management with cache lifetime buffer
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120; // Refresh tokens 120 seconds before expiry
})
.AddClient(ClientCredentialsClientName.Parse("api-client"), client =>
{
    client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
    client.ClientId = ClientId.Parse("my-service");
    client.ClientSecret = ClientSecret.Parse("my-secret");
    client.Scope = Scope.Parse("api1");
});
```

## Encrypted Cache Serializer

```csharp
using System.Buffers;
using System.Text.Json;
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.AspNetCore.DataProtection;

public sealed class EncryptedHybridCacheSerializer : IHybridCacheSerializer<ClientCredentialsToken>
{
    private readonly IDataProtector _protector;

    public EncryptedHybridCacheSerializer(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector("ClientCredentialsToken");
    }

    public ClientCredentialsToken Deserialize(ReadOnlySequence<byte> source)
    {
        var unprotected = _protector.Unprotect(source.ToArray());
        return JsonSerializer.Deserialize<ClientCredentialsToken>(unprotected)!;
    }

    public void Serialize(ClientCredentialsToken value, IBufferWriter<byte> target)
    {
        var json = JsonSerializer.SerializeToUtf8Bytes(value);
        target.Write(_protector.Protect(json));
    }
}
```

## How It Works

1. **`AddStackExchangeRedisCache`** registers Redis as the distributed cache backend. HybridCache automatically picks it up as the L2 tier.

2. **`CacheLifetimeBuffer = 120`** means the library will request a new token 120 seconds before the cached token expires, ensuring the API never receives a near-expired token.

3. **`EncryptedHybridCacheSerializer`** implements `IHybridCacheSerializer<ClientCredentialsToken>` and uses ASP.NET Core Data Protection to encrypt/decrypt tokens before they enter/leave the cache. This prevents other apps sharing the same Redis instance from reading your tokens.

4. **`AddHybridCache().AddSerializer<>()`** registers the custom serializer so HybridCache uses it for all `ClientCredentialsToken` entries.
