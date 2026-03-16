# Token Caching with Redis, HybridCache, and Encryption

In Duende.AccessTokenManagement v4, client credentials tokens are cached using `HybridCache` — a two-tier cache with an in-memory L1 and an optional distributed L2. Here's how to configure Redis as the L2 backend, set a custom cache lifetime buffer, and encrypt cached tokens with Data Protection.

## Package References

```xml
<PackageReference Include="Duende.AccessTokenManagement" Version="4.0.0" />
<PackageReference Include="Microsoft.Extensions.Caching.StackExchangeRedis" Version="9.0.0" />
<PackageReference Include="Microsoft.AspNetCore.DataProtection" Version="9.0.0" />
```

## Program.cs

```csharp
using System.Buffers;
using System.Text.Json;
using Duende.AccessTokenManagement;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Caching.Hybrid;

var builder = WebApplication.CreateBuilder(args);

// ── 1. Redis as the distributed L2 cache tier ──
// HybridCache picks this up automatically as its remote backing store
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// ── 2. Data Protection for encrypting cached tokens ──
builder.Services.AddDataProtection();

// ── 3. Client credentials token management with custom cache buffer ──
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    // Refresh tokens 120 seconds before they expire to avoid serving near-expired tokens
    options.CacheLifetimeBuffer = 120;
})
.AddClient("api.client", client =>
{
    client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
    client.ClientId = ClientId.Parse("my-service");
    client.ClientSecret = ClientSecret.Parse("my-secret");
    client.Scope = Scope.Parse("api1");
});

// ── 4. Register HybridCache with an encrypted serializer for ClientCredentialsToken ──
builder.Services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();

// ── 5. Register HTTP client ──
builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("api.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com/"); });

var app = builder.Build();
app.Run();

// ── Encrypted serializer implementation ──
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

1. **Redis as L2**: `AddStackExchangeRedisCache` registers an `IDistributedCache` backed by Redis. `HybridCache` in v4 automatically picks this up as the remote L2 tier — no explicit registration of `HybridCache` wiring to Redis is needed. The L1 is in-memory by default.

2. **CacheLifetimeBuffer = 120**: Tokens are evicted from cache 120 seconds before their actual expiry. This prevents the library from serving a token that could expire in transit between retrieval and use at the API.

3. **Encrypted serializer**: Since the Redis instance is shared with other applications, implementing `IHybridCacheSerializer<ClientCredentialsToken>` using `IDataProtector` ensures tokens are encrypted at rest. The `AddHybridCache().AddSerializer<>()` call replaces the default serializer for the `ClientCredentialsToken` type only.

4. **Data Protection**: `AddDataProtection()` enables the `IDataProtectionProvider` used by the encrypted serializer. In production, configure a persistent key ring (e.g., Azure Blob Storage + Azure Key Vault) so keys survive app restarts.
