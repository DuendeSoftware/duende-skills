Per v7 the interface has no `CancellationToken` and no `GetAllClientsAsync` (that's v8+).

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;

public class ClientDocument
{
    [BsonId] public string Id { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string? ClientName { get; set; }
    public bool Enabled { get; set; } = true;
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public List<string> RedirectUris { get; set; } = new();
    public List<string> PostLogoutRedirectUris { get; set; } = new();
    public List<string> SecretHashes { get; set; } = new();
    public bool RequireClientSecret { get; set; } = true;
    public bool RequirePkce { get; set; } = true;
}

public sealed class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientStore(IMongoDatabase database)
        => _clients = database.GetCollection<ClientDocument>("clients");

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var doc = await _clients.Find(c => c.ClientId == clientId).FirstOrDefaultAsync();
        return doc is null ? null : Map(doc);
    }

    private static Client Map(ClientDocument d) => new()
    {
        ClientId = d.ClientId,
        ClientName = d.ClientName,
        Enabled = d.Enabled,
        AllowedGrantTypes = d.AllowedGrantTypes,
        AllowedScopes = d.AllowedScopes,
        RedirectUris = d.RedirectUris,
        PostLogoutRedirectUris = d.PostLogoutRedirectUris,
        RequireClientSecret = d.RequireClientSecret,
        RequirePkce = d.RequirePkce,
        ClientSecrets = d.SecretHashes.Select(h => new Secret(h)).ToList()
    };
}
```

Registration (use the builder helper, not `AddTransient`; the cache decorator is added explicitly for custom stores and needs `AddInMemoryCaching()`):
```csharp
builder.Services.AddSingleton<IMongoClient>(new MongoClient(builder.Configuration.GetConnectionString("Mongo")));
builder.Services.AddSingleton(sp => sp.GetRequiredService<IMongoClient>().GetDatabase("identity"));

builder.Services.AddIdentityServer(options =>
    {
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
    })
    .AddClientStore<MongoClientStore>()
    .AddInMemoryCaching()
    .AddClientStoreCache<MongoClientStore>();
```
Note the cache is node-local; use a distributed cache if you run several nodes. Stored secrets should be hashed.
