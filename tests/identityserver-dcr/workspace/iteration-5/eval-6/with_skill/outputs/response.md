# Custom `IClientConfigurationStore` backed by MongoDB

When you want a non-relational backing store for dynamically registered clients, implement `IClientConfigurationStore` yourself. The interface has four methods covering the full client lifecycle: add, find, update, delete.

## The interface

```csharp
public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
    Task<Client?> FindByClientIdAsync(string clientId);
    Task UpdateAsync(Client client);
    Task DeleteAsync(string clientId);
}
```

## MongoDB implementation skeleton

```csharp
using Duende.IdentityServer.Configuration.Stores;
using Duende.IdentityServer.Models;
using MongoDB.Driver;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<Client> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<Client>("clients");
    }

    public async Task AddAsync(Client client)
    {
        // Persist a newly registered client.
        // IMPORTANT: hash any client secrets before storing them (see note below).
        await _clients.InsertOneAsync(client);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        // Return the client, or null when not found.
        return await _clients
            .Find(c => c.ClientId == clientId)
            .FirstOrDefaultAsync();
    }

    public async Task UpdateAsync(Client client)
    {
        // Replace the existing document for this client.
        await _clients.ReplaceOneAsync(
            c => c.ClientId == client.ClientId,
            client);
    }

    public async Task DeleteAsync(string clientId)
    {
        // Remove the client from the store.
        await _clients.DeleteOneAsync(c => c.ClientId == clientId);
    }
}
```

## Register it in DI

Register the Mongo driver types and your store. Register the store **after** `AddIdentityServerConfiguration()` so it replaces the default `IClientConfigurationStore`:

```csharp
builder.Services.AddSingleton<IMongoClient>(
    new MongoClient(builder.Configuration.GetConnectionString("Mongo")));
builder.Services.AddScoped(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("identityserver"));

builder.Services.AddIdentityServerConfiguration();
builder.Services.AddScoped<IClientConfigurationStore, MongoClientConfigurationStore>();
```

## Security note — store secrets securely

Dynamically registered clients are issued generated secrets. **Do not persist them in plaintext.** Store only a hash of each secret (Duende's `Client.ClientSecrets` uses hashed values via `Secret(value.Sha256())`), so a database compromise doesn't leak usable credentials. Consider mapping `Client` to a dedicated Mongo document type if you want explicit control over how secrets and other fields are serialized.

That covers all four `IClientConfigurationStore` methods with a MongoDB backing collection, plus the DI wiring.
