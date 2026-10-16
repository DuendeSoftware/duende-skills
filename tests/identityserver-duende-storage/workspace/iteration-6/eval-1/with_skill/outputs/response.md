Duende Storage is a **preview** feature (IdentityServer 8.1 previews), so use `--prerelease`.

## Packages
```bash
dotnet add package Duende.IdentityServer --prerelease
dotnet add package Duende.Storage.Sqlite --prerelease
```
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.1.0-preview.*" />
<PackageReference Include="Duende.Storage.Sqlite" Version="8.1.0-preview.*" />
```
(Use whatever preview version NuGet gives you.)

## appsettings.json
```json
{ "ConnectionStrings": { "IdentityServer": "Data Source=identityserver.db" } }
```

## Program.cs
```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.Storage.Schema;
using Duende.Storage.Sqlite;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddStorage(storage =>
        storage.AddSqlite(options =>
            options.ConnectionString =
                builder.Configuration.GetConnectionString("IdentityServer")
                ?? throw new InvalidOperationException("IdentityServer connection string is missing.")))
    .AddConfigurationStorage()   // clients, resources, IdPs, CORS + admin APIs
    .AddOperationalStorage()     // grants, device flow, PAR, sessions store, signing keys
    .AddServerSideSessions();    // needed to actually enable server-side sessions

builder.Services.AddRazorPages();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    await app.Services.GetRequiredService<IStorageInstanceSchema>().MigrateAsync(CancellationToken.None);
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Notes
- `AddStorage(...)` only **selects the database provider**. Nothing is stored until `AddConfigurationStorage()` and `AddOperationalStorage()` route data to it. Forgetting them is the classic mistake.
- I removed the `AddInMemory*` calls, since configuration now comes from the database. Seed the old `Config` data through the admin APIs (`IClientAdmin`, `IApiScopeAdmin`, `IIdentityResourceAdmin`, `IApiResourceAdmin`), creating scopes and identity resources first. The in-memory secrets must be provisioned as plaintext through `CreateClientSecret.PlaintextValue`, which is hashed on write. Alternatively, keep `.AddInMemoryClients(Config.Clients)` after `AddConfigurationStorage()` to override just the client store.
- `MigrateAsync` needs DDL rights. That's fine for SQLite in dev. In production, run it as a deployment step (e.g. `duende storage migrate`).
- A background purge service runs hourly for expired data (configurable via `StoragePurgeOptions`).
- The EF Core provider remains fully supported. Duende Storage is opt-in.
