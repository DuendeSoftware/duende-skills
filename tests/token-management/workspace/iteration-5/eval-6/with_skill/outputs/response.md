# Token Caching for Multi-Instance Production: Redis + Encryption

For a multi-instance deployment, v4 uses `HybridCache` — an L1 in-memory tier plus an L2 distributed tier. Registering `AddStackExchangeRedisCache` gives you the shared L2 tier that HybridCache picks up automatically. Since Redis is shared with other apps, encrypt the cached tokens with a custom `IHybridCacheSerializer<ClientCredentialsToken>` backed by Data Protection.

## `Program.cs`

```csharp
using System.Buffers;
using System.Text.Json;
using Duende.AccessTokenManagement;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Caching.Hybrid;

var builder = WebApplication.CreateBuilder(args);

// ✅ L2 distributed cache — HybridCache uses this as its remote tier automatically
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// ✅ Token management with a 120s lifetime buffer (refresh 120s before expiry)
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120;
})
.AddClient("catalog.client", client =>
{
    client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
    client.ClientId     = ClientId.Parse("catalog-worker");
    client.ClientSecret = ClientSecret.Parse("worker-secret");
    client.Scope        = Scope.Parse("catalog:read");
});

// ✅ Data Protection provider used by the encrypting serializer
builder.Services.AddDataProtection();

// ✅ Register a custom HybridCache serializer for ClientCredentialsToken that
//    encrypts/decrypts values at rest so other apps sharing Redis can't read them
builder.Services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();

var app = builder.Build();
app.Run();
```

## The encrypting serializer

```csharp
public sealed class EncryptedHybridCacheSerializer
    : IHybridCacheSerializer<ClientCredentialsToken>
{
    private readonly IDataProtector _protector;

    public EncryptedHybridCacheSerializer(IDataProtectionProvider provider)
    {
        // Purpose string isolates this protector from other Data Protection consumers
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

## How the pieces fit

| Requirement | Implementation |
|---|---|
| Distributed L2 cache backend | `AddStackExchangeRedisCache(...)` with the `Redis` connection string; HybridCache adopts it as L2 |
| 120-second lifetime buffer | `options.CacheLifetimeBuffer = 120` on `AddClientCredentialsTokenManagement` |
| Encryption at rest on shared Redis | `EncryptedHybridCacheSerializer : IHybridCacheSerializer<ClientCredentialsToken>` using `IDataProtector` |
| Serializer wiring | `AddHybridCache().AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>()` |
| Data protection provider | `AddDataProtection()` |

> **Production note:** in a multi-instance deployment, persist Data Protection keys to a shared, durable location (e.g. `PersistKeysToStackExchangeRedis` or a blob/file share with `ProtectKeysWithAzureKeyVault`). Otherwise each instance generates its own keyring and can't decrypt tokens written by another instance. Keep `CacheLifetimeBuffer` positive (here 120s) so a token never expires in transit between retrieval and use.
