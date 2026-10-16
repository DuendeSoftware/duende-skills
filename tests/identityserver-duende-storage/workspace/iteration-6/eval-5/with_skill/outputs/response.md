Use **two storage instances** (Duende Storage, preview). `AddStorage` selects a provider per instance. A data category (`configuration`, `operational`) maps to one instance through the router.

```csharp
using Duende.IdentityServer;
using Duende.Storage;
using Duende.Storage.Schema;
using Duende.Storage.Sqlite; // or MsSql / PostgreSql / Oracle

var configConn = builder.Configuration.GetConnectionString("Config")!;
var opsConn    = builder.Configuration.GetConnectionString("Operational")!;
var operationalInstanceId = StorageInstanceId.Create("operational");

builder.Services.AddIdentityServer()
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = configConn))   // default instance
    .AddConfigurationStorage()                                                          // -> default
    .AddStorage(operationalInstanceId, storage => storage.AddSqlite(o => o.ConnectionString = opsConn))
    .AddOperationalStorage(operationalInstanceId)                                       // grants, sessions, keys -> operational
    .AddServerSideSessions();
```
`AddOperationalStorage` covers persisted grants, device flow, PAR, server-side session store and signing keys.

## Migrating both
`IStorageInstanceSchema.MigrateAsync` migrates **only the default instance**. For named instances, use the factory, and migrate **every** instance:

```csharp
var ct = CancellationToken.None;
var factory = app.Services.GetRequiredService<IStorageInstanceSchemaFactory>();
await (await factory.GetStorageInstanceSchema(StorageInstanceId.Default, ct)).MigrateAsync(ct);
await (await factory.GetStorageInstanceSchema(operationalInstanceId, ct)).MigrateAsync(ct);
```
Fine in development. Run only one migration process at a time. In production, migrate as a deployment step. The CLI handles one connection string at a time, so run it per instance:
```bash
dotnet tool install --global Duende.Cli --prerelease
DUENDE_STORAGE_CONNECTION_STRING="$CONFIG_CONN" duende storage migrate --provider postgresql --dry-run
DUENDE_STORAGE_CONNECTION_STRING="$CONFIG_CONN" duende storage migrate --provider postgresql
DUENDE_STORAGE_CONNECTION_STRING="$OPS_CONN"    duende storage migrate --provider postgresql
```
(Oracle isn't supported by the CLI; use `BuildMigrationScript` and a DBA.)

**Rules:**
- Each category maps to **one** instance per app. Mapping it twice to different instances, or selecting a second provider for the same instance, throws `InvalidOperationException`.
- Purge and outbox processing discover all instances automatically. Purge runs hourly by default (`StoragePurgeOptions`).
- If you add User Management, `AddUserManagement(...)` reuses the default instance unless you give it its own instance id.
