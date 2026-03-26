# MongoDB Client Store

```csharp
using MongoDB.Driver;

public class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<Client> _clients;

    public MongoClientStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<Client>("clients");
    }

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    {
        return await _clients.Find(c => c.ClientId == clientId).FirstOrDefaultAsync(ct);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddClientStore<MongoClientStore>();

// Add caching
builder.Services.AddMemoryCache();
builder.Services.AddIdentityServer(options =>
{
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
});
```