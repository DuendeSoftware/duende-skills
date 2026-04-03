# MongoDB Client Store

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<BsonDocument> _clients;

    public MongoClientStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<BsonDocument>("clients");
    }

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    {
        var filter = Builders<BsonDocument>.Filter.Eq("clientId", clientId);
        var doc = await _clients.Find(filter).FirstOrDefaultAsync(ct);
        if (doc == null) return null;

        return new Client
        {
            ClientId = doc["clientId"].AsString,
            ClientName = doc["clientName"].AsString
        };
    }
}
```

Register:
```csharp
builder.Services.AddIdentityServer()
    .AddClientStore<MongoClientStore>();

// For caching, you could add memory cache:
builder.Services.AddMemoryCache();
```

This gives you a basic MongoDB-backed client store. You may want to add caching to reduce database calls.
