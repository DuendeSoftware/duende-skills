# Custom MongoDB Client Store

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public class MongoClientStore : IClientStore
{
    private readonly IMongoDatabase _database;

    public MongoClientStore(IMongoDatabase database)
    {
        _database = database;
    }

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken cancellationToken = default)
    {
        var collection = _database.GetCollection<BsonDocument>("clients");
        var filter = Builders<BsonDocument>.Filter.Eq("ClientId", clientId);
        var doc = await collection.Find(filter).FirstOrDefaultAsync(cancellationToken);
        
        if (doc == null) return null;
        
        return new Client
        {
            ClientId = doc["ClientId"].AsString,
            ClientName = doc["ClientName"].AsString
        };
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddClientStore<MongoClientStore>();

builder.Services.AddMemoryCache();
```

Register the custom store with `AddClientStore<T>()` and add memory caching for performance.
