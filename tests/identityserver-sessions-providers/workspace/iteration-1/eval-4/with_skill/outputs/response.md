# Converting to Dynamic Identity Providers

Dynamic identity providers solve the performance issue of registering hundreds of static authentication handlers. They require the **Enterprise Edition** license.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(Config.Clients)
    // Configure EF Core stores for dynamic providers
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name));
    })
    // Cache dynamic provider lookups for performance
    .AddConfigurationStoreCache();

// Remove static OIDC registrations — replaced by dynamic providers
// The Google handler still needs static registration for its handler type,
// but OIDC providers like EntraId move to dynamic configuration
builder.Services.AddAuthentication()
    .AddGoogle("Google", options =>
    {
        options.ClientId = builder.Configuration["ExternalProviders:Google:ClientId"]!;
        options.ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"]!;
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
    });
    // EntraId OIDC provider is now dynamic — removed from static registration

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

// Seed dynamic providers
await SeedDynamicProviders(app);

app.Run();

static async Task SeedDynamicProviders(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();

    if (!context.IdentityProviders.Any())
    {
        context.IdentityProviders.Add(new OidcProvider
        {
            Scheme = "demoidsrv",
            DisplayName = "Demo IdentityServer",
            Authority = "https://demo.duendesoftware.com",
            ClientId = "login",
            Enabled = true
        }.ToEntity());

        await context.SaveChangesAsync();
    }
}
```

## Key Changes

1. **Removed static `AddOpenIdConnect("EntraId", ...)` registration** — replaced by dynamic provider loaded from the database
2. **`AddConfigurationStore(...)`** — Stores dynamic provider configuration in SQL Server via the `ConfigurationDbContext`
3. **`AddConfigurationStoreCache()`** — Caches provider lookups to avoid hitting the database on every authentication request
4. **Seed data** — Creates an `OidcProvider` entity with `Scheme = "demoidsrv"`, `Authority = "https://demo.duendesoftware.com"`, and `ClientId = "login"`

## Important Notes

- **Enterprise Edition required**: Dynamic identity providers are an Enterprise Edition feature
- Dynamic OIDC providers follow the callback path convention `/federation/{scheme}/signin`
- The `ConfigurationDbContext` is used for both dynamic providers and other configuration data (clients, resources)
- Non-OIDC providers (like Google) require custom provider type registration via `AddProviderType<THandler, TOptions, TIdentityProvider>()`