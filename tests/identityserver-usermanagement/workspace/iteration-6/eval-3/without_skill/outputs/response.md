I'm not sure of the exact Duende User Management API; verify names with the docs.

```
dotnet add package Duende.UserManagement
dotnet add package Duende.UserManagement.PostgreSql   # approximate
```
```csharp
builder.Services.AddUserManagement()
    .AddPostgreSqlStore(builder.Configuration.GetConnectionString("UserManagement"));
```
```json
"ConnectionStrings": { "UserManagement": "Host=db;Database=usermgmt;Username=app;Password=..." }
```
**Migrations:** If the store is EF Core-based, yes: for production, generate and apply migrations explicitly (`dotnet ef migrations add ... ` / `dotnet ef database update` or a migration bundle in your deploy pipeline) rather than auto-creating at runtime. Check whether the library ships its own migrations or schema bootstrap; if so follow that. Use a least-privileged runtime DB account, and back up the DB.
