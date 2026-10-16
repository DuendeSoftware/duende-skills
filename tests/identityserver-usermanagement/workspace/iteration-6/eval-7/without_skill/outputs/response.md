Likely cause: `AddSqliteStore` isn't an option inside the `AddUserManagement` options lambda; the lambda only configures options. Storage is registered on the builder returned by `AddUserManagement(...)` (or separately), and the database is created/migrated at startup, so nothing happens if the store was never registered. (I'm not sure of the exact API.)

```csharp
builder.Services.AddUserManagement(options => { /* options only */ })
    .AddSqliteStore("Data Source=usermanagement.db");
```
Then ensure the database is created/migrated at startup (e.g., a migration call or `EnsureCreated`, as documented). Also check the connection string and file write permissions.
