# Custom MongoDB Client Store

```csharp
public class MongoClientStore : IClientConfigurationStore
{
    private readonly IMongoCollection<BsonDocument> _collection;

    public MongoClientStore(IMongoDatabase db)
    {
        _collection = db.GetCollection<BsonDocument>("clients");
    }

    public async Task AddAsync(Client client)
    {
        var doc = client.ToBsonDocument();
        await _collection.InsertOneAsync(doc);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var filter = Builders<BsonDocument>.Filter.Eq("ClientId", clientId);
        var doc = await _collection.Find(filter).FirstOrDefaultAsync();
        return doc == null ? null : BsonSerializer.Deserialize<Client>(doc);
    }

    public async Task UpdateAsync(Client client)
    {
        var filter = Builders<BsonDocument>.Filter.Eq("ClientId", client.ClientId);
        await _collection.ReplaceOneAsync(filter, client.ToBsonDocument());
    }

    public async Task DeleteAsync(string clientId)
    {
        var filter = Builders<BsonDocument>.Filter.Eq("ClientId", clientId);
        await _collection.DeleteOneAsync(filter);
    }
}
```

Register it:
```csharp
builder.Services.AddSingleton<IClientConfigurationStore, MongoClientStore>();
```
