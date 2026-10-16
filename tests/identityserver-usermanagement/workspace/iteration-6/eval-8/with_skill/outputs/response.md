Because `AddStorage(...)` already registered a provider for the **default** instance, there are two options:

- **Shared (default)**: call `AddUserManagement(...)` without a second provider; it shares the DB/schema. Calling `AddStorage` again for the same instance throws `InvalidOperationException`.
- **Dedicated database (what you want)**: register a **named** storage instance for User Management.

```csharp
var umInstance = StorageInstanceId.Create("user-management");

builder.Services.AddKeyedSingleton<NpgsqlDataSource>(umInstance.Value, (sp, _) =>
    new NpgsqlDataSourceBuilder(builder.Configuration.GetConnectionString("UserManagement")).Build());

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    // existing default instance
    .AddStorage(storage => { /* existing provider */ })
    .AddConfigurationStorage()
    .AddOperationalStorage()
    // dedicated instance for User Management
    .AddStorage(umInstance, storage =>
        storage.AddPostgreSql(sp => sp.GetRequiredKeyedService<NpgsqlDataSource>(umInstance.Value)))
    .AddUserManagement(umInstance, um => { });
```
Package: `Duende.Storage.PostgreSql` (+ `Duende.UserManagement.IdentityServer8`).

## Migration
No EF migrations, but you must create the schema for that instance explicitly — migrating the default instance does not cover it:
```csharp
var factory = scope.ServiceProvider.GetRequiredService<IStorageInstanceSchemaFactory>();
var schema = await factory.GetStorageInstanceSchema(umInstance, CancellationToken.None);
await schema.MigrateAsync(CancellationToken.None);
```
`MigrateAsync` is idempotent (advisory locks on PostgreSQL); run it as a deployment step in production, and use `CheckVersionAsync` (`IsCompatible`/`CurrentVersion`/`RequiredVersion`) for a startup check. Migrate the default instance separately as you already do.
