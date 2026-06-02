// Program.cs — IdentityServer v7.4 project with custom services (upgrade target)
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
    });

// Custom services using v7 APIs
builder.Services.AddTransient<IClientStore, CustomClientStore>();
builder.Services.AddSingleton<IClock, CustomClock>();
builder.Services.AddTransient<ICache<Client>, CustomClientCache>();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();

// Custom implementations using v7 APIs
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId);
    }
}

public class CustomClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

public class CustomClientCache : ICache<Client>
{
    public Task<Client?> GetOrAddAsync(string key, TimeSpan duration, Func<Task<Client?>> factory)
    {
        // Simple pass-through for demo
        return factory();
    }

    public Task SetAsync(string key, Client item, TimeSpan expiration)
        => Task.CompletedTask;

    public Task<Client?> GetAsync(string key)
        => Task.FromResult<Client?>(null);

    public Task RemoveAsync(string key)
        => Task.CompletedTask;
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<Client> Clients => Set<Client>();
}

// Configuration
public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "web",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        }
    ];
}
