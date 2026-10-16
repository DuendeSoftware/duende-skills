I'm unsure of the exact API; verify against docs. Approach: give User Management its own store registration with a separate PostgreSQL connection string, independent of the Duende Storage config.

```csharp
builder.Services.AddIdentityServer()
    .AddStorage(...)               // existing
    .AddConfigurationStorage(...)
    .AddOperationalStorage(...);

builder.Services.AddUserManagement()
    .AddPostgreSqlStore(builder.Configuration.GetConnectionString("UserManagementDb"));
```
```json
"ConnectionStrings": { "UserManagementDb": "Host=um-db;Database=usermgmt;Username=...;Password=..." }
```
Migrate: use the provider's migration mechanism—with EF Core, `dotnet ef migrations add` against the User Management DbContext with its own connection and run `dotnet ef database update` or a bundle in deployment. Keep the two databases' migrations separate.
