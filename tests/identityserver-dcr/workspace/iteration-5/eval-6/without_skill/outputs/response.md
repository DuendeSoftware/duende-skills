# Custom `IClientConfigurationStore` with MongoDB

Duende resolves an `IClientConfigurationStore` to persist clients created through Dynamic Client Registration. To swap SQL Server for MongoDB, implement that interface against a Mongo collection and register your implementation in DI.

## The interface

The store is responsible for the client lifecycle — creating, looking up, updating, and removing dynamically registered clients:

```csharp
public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
    Task<Client?> FindByClientIdAsync(string clientId);
    Task UpdateAsync(Client client);
    Task DeleteAsync(string clientId);
}
```

## MongoDB implementation

```csharp
using Duende.IdentityServer.Models;
using MongoDB.Driver;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<Client> _collection;

    public MongoClientConfigurationStore(IMongoDatabase db)
    {
        _collection = db.GetCollection<Client>("clients");
    }

    public Task AddAsync(Client client)
    {
        // Ensure secrets are hashed before this point — never store plaintext secrets.
        return _collection.InsertOneAsync(client);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var cursor = await _collection.FindAsync(c => c.ClientId == clientId);
        return await cursor.FirstOrDefaultAsync(); // returns null when not found
    }

    public Task UpdateAsync(Client client)
    {
        return _collection.ReplaceOneAsync(c => c.ClientId == client.ClientId, client);
    }

    public Task DeleteAsync(string clientId)
    {
        return _collection.DeleteOneAsync(c => c.ClientId == clientId);
    }
}
```

## DI registration

```csharp
var mongoConn = builder.Configuration.GetConnectionString("Mongo");
builder.Services.AddSingleton<IMongoClient>(new MongoClient(mongoConn));
builder.Services.AddScoped(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("identityserver"));

// Replace the default store with the Mongo-backed one
builder.Services.AddScoped<IClientConfigurationStore, MongoClientConfigurationStore>();
```

## Important: secret storage

DCR issues clients a generated secret. **Store secrets hashed, never in plaintext.** In Duende, `Client.ClientSecrets` holds secret *values* that should already be hashed (e.g. `new Secret(value.Sha256())`). If you serialize the `Client` directly, make sure the persisted secret values are the hashes, so a database leak doesn't expose usable credentials. You may also want a dedicated Mongo document/DTO to control exactly how the client is serialized rather than persisting the raw `Client` model.

That's a complete skeleton: the four interface methods over a Mongo collection, plus DI wiring and a secret-handling caveat. Confirm the exact `IClientConfigurationStore` method signatures against your installed Duende version.
