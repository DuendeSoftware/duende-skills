Here's a custom `IClientStore` implementation that pulls clients from a MongoDB `clients` collection and maps them to Duende's `Client` model, plus the registration with caching. Since you're on **IdentityServer v7**, the store method signature omits the `CancellationToken` parameter.

## MongoClientStore.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<MongoClient> _collection;

    public MongoClientStore(IMongoDatabase database)
    {
        _collection = database.GetCollection<MongoClient>("clients");
    }

    // v7: no CancellationToken parameter on the interface.
    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var mongoClient = await _collection
            .Find(x => x.ClientId == clientId)
            .FirstOrDefaultAsync();

        if (mongoClient is null)
            return null;

        return MapToClient(mongoClient);
    }

    private static Client MapToClient(MongoClient source)
    {
        var client = new Client
        {
            ClientId = source.ClientId,
            Enabled = source.Enabled,
            AllowedGrantTypes = source.AllowedGrantTypes
        };

        foreach (var scope in source.AllowedScopes)
            client.AllowedScopes.Add(scope);

        foreach (var secret in source.ClientSecrets)
            client.ClientSecrets.Add(new Secret(secret.Sha256()));

        return client;
    }
}
```

## The Mongo document type

```csharp
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

public class MongoClient
{
    [BsonId]
    public ObjectId Id { get; set; }

    public string ClientId { get; set; } = string.Empty;
    public bool Enabled { get; set; } = true;
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public List<string> ClientSecrets { get; set; } = new();
}
```

## Registration (Program.cs)

```csharp
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);

// Provide the IMongoDatabase for constructor injection.
builder.Services.AddSingleton<IMongoClient>(
    new MongoDB.Driver.MongoClient(builder.Configuration.GetConnectionString("Mongo")));
builder.Services.AddScoped(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("identityserver"));

builder.Services.AddIdentityServer(options =>
    {
        // Cache clients for 5 minutes.
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
    })
    .AddClientStore<MongoClientStore>()
    .AddInMemoryCaching()
    .AddClientStoreCache<MongoClientStore>();

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Explanation

- **`AddClientStore<MongoClientStore>()`** registers the custom store with IdentityServer.
- **`AddInMemoryCaching()`** registers the in-memory cache backing, and **`AddClientStoreCache<MongoClientStore>()`** wraps the store in a caching decorator so repeated lookups for the same client don't hit MongoDB.
- **`options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5)`** sets the 5-minute cache lifetime.
- The `FindClientByIdAsync(string clientId)` signature has no `CancellationToken` because that overload only exists in IdentityServer v8+.
