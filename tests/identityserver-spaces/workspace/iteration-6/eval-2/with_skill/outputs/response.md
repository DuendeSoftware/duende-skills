# Duende.Spaces + SQLite: tenant `Acme` at https://login.example.com/t/acme

Spaces are a preview, licensed add-on built on Duende Storage pools.

```bash
dotnet add package Duende.IdentityServer --prerelease
dotnet add package Duende.Storage.Sqlite --prerelease
dotnet add package Duende.Spaces --prerelease
```

## Program.cs
```csharp
using System.Net;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("Storage") ?? "Data Source=identityserver.db";

builder.Services.AddRazorPages();

builder.Services
    .AddIdentityServer()                      // do NOT set IssuerUri
    .AddServerSideSessions()
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = connectionString))
    .AddConfigurationStorage()
    .AddOperationalStorage();

builder.Services.AddSpaces();
builder.Services.Configure<SpacesOptions>(options =>
{
    options.SpacePathPrefix = "/t";        // default
    options.FallbackToDefault = false;     // default: strict 404
});
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost | ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42")); // your proxy
    options.ForwardLimit = 1;
});

var app = builder.Build();

await app.Services.GetRequiredService<IStorageInstanceSchema>().MigrateAsync(CancellationToken.None);

// Idempotent provisioning (run from a single deployment process)
var spaces = app.Services.GetRequiredService<ISpaceAdmin>();
var existing = await spaces.QueryAsync(
    QueryRequest.Create<SpaceFilter, SpaceSortField>(new SpaceFilter { Name = "Acme" }), CancellationToken.None);

if (!existing.Items.Any(s => string.Equals(s.Name, "Acme", StringComparison.Ordinal)))
{
    var result = await spaces.CreateAsync(new CreateSpaceConfiguration
    {
        Name = "Acme",
        MatchPatterns =
        [
            new SpaceMatchPattern { Origin = "https://login.example.com", Path = "/acme" }
        ]
    }, CancellationToken.None);

    if (!result.IsSuccess)
        throw new InvalidOperationException($"Could not create the Acme space: {result.Errors}");
}

app.UseStaticFiles();
app.UseForwardedHeaders();   // 1. public scheme/host first
app.UseSpaceResolution();    // 2. before UseRouting: path matches rewrite PathBase/Path
app.UseRouting();            // 3.
app.UseIdentityServer();     // 4.
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Notes
- **Middleware order**: `UseForwardedHeaders` → `UseSpaceResolution` → `UseRouting` → `UseIdentityServer`. Wrong order breaks resolution because the resolver must see the public scheme/host, and path matching rewrites `PathBase`.
- The pattern requires **both** origin and path to match; `/acme` combined with the default `/t` prefix serves `https://login.example.com/t/acme/.well-known/openid-configuration` from Acme's pool. Issuer = `https://login.example.com/t/acme`.
- Requests with the `/t/...` prefix but no matching space return 404.
- Leave `IssuerUri` unset; a fixed value makes every space return the same issuer.
- Provisioning is query-then-create so it's idempotent; keep it in one process to avoid races. Move it to a trusted admin path for production and authorize it per space.
- Create Acme's clients inside the space, and point client authority at `https://login.example.com/t/acme`.
- `appsettings.json`: add `"ConnectionStrings": { "Storage": "Data Source=identityserver.db" }`.
