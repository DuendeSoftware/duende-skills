Below is a custom `IClientStore` that reads client definitions from a MongoDB `clients` collection, maps them to Duende `Client` models, and registers it with in-memory caching set to a 5-minute expiration. Because you are targeting **IdentityServer v7**, the interface methods do **not** take a `CancellationToken` (that parameter was added in v8), and `GetAllClientsAsync` is not part of the v7 interface.

## MongoClientStore.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public sealed class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("clients");
    }

    // v7 signature: no CancellationToken parameter.
    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var doc = await _clients
            .Find(c => c.ClientId == clientId)
            .FirstOrDefaultAsync();

        return doc?.ToIdentityServerClient();
    }
}
```

## The MongoDB document + mapping

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

public sealed class ClientDocument
{
    [BsonId]
    public ObjectId Id { get; set; }

    public string ClientId { get; set; } = default!;
    public string[] AllowedGrantTypes { get; set; } = [];
    public string[] AllowedScopes { get; set; } = [];
    public string[] ClientSecrets { get; set; } = [];
    public bool Enabled { get; set; } = true;

    public Client ToIdentityServerClient() => new()
    {
        ClientId = ClientId,
        Enabled = Enabled,
        AllowedGrantTypes = AllowedGrantTypes,
        AllowedScopes = { },  // populated below
        ClientSecrets = { }
    }.WithScopesAndSecrets(AllowedScopes, ClientSecrets);
}

internal static class ClientMappingExtensions
{
    public static Client WithScopesAndSecrets(this Client client, string[] scopes, string[] secrets)
    {
        foreach (var s in scopes) client.AllowedScopes.Add(s);
        foreach (var secret in secrets) client.ClientSecrets.Add(new Secret(secret.Sha256()));
        return client;
    }
}
```

## Registration in Program.cs

Register the `IMongoDatabase`, add the custom store via the `AddClientStore<T>` helper, and wrap it with the caching decorator. `AddInMemoryCaching()` is required whenever you wrap a **custom** store with `AddClientStoreCache<T>()`. Cache expiration is controlled through `IdentityServerOptions.Caching`.

```csharp
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);

// MongoDB registration
builder.Services.AddSingleton<IMongoClient>(
    _ => new MongoClient(builder.Configuration.GetConnectionString("Mongo")));
builder.Services.AddScoped<IMongoDatabase>(
    sp => sp.GetRequiredService<IMongoClient>().GetDatabase("identityserver"));

builder.Services.AddIdentityServer(options =>
    {
        // 5-minute client cache expiration
        options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
    })
    .AddClientStore<MongoClientStore>()   // register the custom store
    .AddInMemoryCaching()                 // required for custom-store caching
    .AddClientStoreCache<MongoClientStore>(); // wrap the store with a caching decorator

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Key points

- **v7 target → no `CancellationToken`.** `FindClientByIdAsync(string clientId)` matches the v7 `IClientStore` signature exactly. Adding a `CancellationToken` (or implementing `GetAllClientsAsync`) would only be correct for v8+.
- **`AddClientStore<MongoClientStore>()`** registers the store through the IdentityServer builder rather than a raw `AddTransient`, so it participates correctly in the store pipeline.
- **`AddInMemoryCaching()` + `AddClientStoreCache<MongoClientStore>()`** is the correct pairing for caching a custom store. `AddInMemoryCaching()` supplies the `IMemoryCache`-backed `ICache<T>` that the decorator uses.
- **`options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5)`** sets the 5-minute expiration window.
