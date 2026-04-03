# Token Caching with Redis and Data Protection Encryption

Here's how to configure v4 of Duende.AccessTokenManagement with Redis as the distributed cache, a cache lifetime buffer of 120 seconds, and encrypted token storage using Data Protection.

## `Program.cs`

```csharp
using System.Buffers;
using System.Text.Json;
using Duende.AccessTokenManagement;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Caching.Hybrid;

var builder = WebApplication.CreateBuilder(args);

// Register Redis as the distributed L2 cache tier for HybridCache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// Register Data Protection for encrypting cached tokens
builder.Services.AddDataProtection();

// Register client credentials token management with 120s cache lifetime buffer
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    // Refresh tokens 120 seconds before they expire
    options.CacheLifetimeBuffer = 120;
})
.AddClient("api.client", client =>
{
    client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
    client.ClientId = ClientId.Parse("my-service");
    client.ClientSecret = ClientSecret.Parse("my-secret");
    client.Scope = Scope.Parse("api1");
});

// Register the encrypted HybridCache serializer for ClientCredentialsToken
builder.Services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();

builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("api.client"),
    client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/");
    });

var app = builder.Build();
app.Run();
```

## Encrypted HybridCache Serializer

```csharp
using System.Buffers;
using System.Text.Json;
using Duende.AccessTokenManagement;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Caching.Hybrid;

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

## Key Points

1. **`AddStackExchangeRedisCache`** registers Redis as the distributed L2 cache tier. v4's `HybridCache` automatically picks it up — no `AddDistributedMemoryCache()` needed.
2. **`CacheLifetimeBuffer = 120`** configures the library to refresh tokens 120 seconds before they expire, ensuring a fresh token is always available.
3. **`IHybridCacheSerializer<ClientCredentialsToken>`** — The `EncryptedHybridCacheSerializer` uses `IDataProtector` to encrypt tokens before they are stored in the cache and decrypt them on retrieval.
4. **`AddHybridCache().AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>()`** registers the custom serializer with the HybridCache infrastructure.
5. **`AddDataProtection()`** enables the Data Protection provider, which is required for the encryption/decryption.

## Packages Required

```xml
<PackageReference Include="Duende.AccessTokenManagement" Version="4.0.0" />
<PackageReference Include="Microsoft.Extensions.Caching.StackExchangeRedis" Version="9.0.0" />
```
