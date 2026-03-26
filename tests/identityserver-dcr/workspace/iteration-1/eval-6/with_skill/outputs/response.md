# Custom IClientConfigurationStore for MongoDB

Here's a skeleton implementation:

```csharp
public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("dcr_clients");
    }

    public async Task AddAsync(Client client)
    {
        var document = MapToDocument(client);
        await _clients.InsertOneAsync(document);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var document = await _clients
            .Find(d => d.ClientId == clientId)
            .FirstOrDefaultAsync();

        return document is null ? null : MapToClient(document);
    }

    public async Task UpdateAsync(Client client)
    {
        var document = MapToDocument(client);
        await _clients.ReplaceOneAsync(
            d => d.ClientId == client.ClientId,
            document);
    }

    public async Task DeleteAsync(string clientId)
    {
        await _clients.DeleteOneAsync(d => d.ClientId == clientId);
    }

    private ClientDocument MapToDocument(Client client)
    {
        return new ClientDocument
        {
            ClientId = client.ClientId,
            ClientName = client.ClientName,
            // Map all relevant properties...
            // IMPORTANT: Client secrets are already hashed by IdentityServer
            // before reaching the store. Store the hashed values as-is.
            SecretHashes = client.ClientSecrets
                .Select(s => s.Value)
                .ToList()
        };
    }

    private Client MapToClient(ClientDocument doc)
    {
        return new Client
        {
            ClientId = doc.ClientId,
            ClientName = doc.ClientName,
            // Map back...
        };
    }
}
```

## Registration

```csharp
builder.Services.AddSingleton<IClientConfigurationStore, MongoClientConfigurationStore>();
```

## Security Note

Client secrets should be stored securely. IdentityServer hashes secrets before passing them to the store, so the values in `ClientSecrets` are already SHA-256 hashes. Store these hashed values as-is — never store plaintext secrets.
