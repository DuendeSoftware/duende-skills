## Storage configuration
```bash
dotnet add package Duende.Storage.PostgreSql
```
PostgreSQL is the recommended production provider (native JSONB). Storage is selected on the IdentityServer builder with `AddStorage`, **not** inside `AddUserManagement`, and requires an `NpgsqlDataSource` in DI.

```csharp
builder.Services.AddNpgsqlDataSource(builder.Configuration.GetConnectionString("Users")!);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddStorage(storage => storage.AddPostgreSql())   // optional: SchemaName option
    .AddUserManagement(options => { /* auth options, e.g. SMTP OTP dispatcher */ });
```

## Migrations?
There are **no EF Core migrations** (storage is document-based), but the schema is **not created automatically**. You must call `IStorageInstanceSchema.MigrateAsync()` — if you skip it, the tables won't exist.

```csharp
using var scope = app.Services.CreateScope();
var factory = scope.ServiceProvider.GetRequiredService<IStorageInstanceSchemaFactory>();
var schema = await factory.GetStorageInstanceSchema(CancellationToken.None);
await schema.MigrateAsync(CancellationToken.None);
```
- Idempotent, uses advisory locks on PostgreSQL, so concurrent instances are safe.
- For production, run it as a separate deployment step (a migration job) rather than at app startup, with a privileged DB account; run the app with a lower-privileged one.
- `schema.CheckVersionAsync()` returns `IsCompatible`/`CurrentVersion`/`RequiredVersion`, useful as a startup compatibility check.
