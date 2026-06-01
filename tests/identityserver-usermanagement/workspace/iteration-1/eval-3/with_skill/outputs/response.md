# PostgreSQL Storage for Duende User Management

## 1. Add the PostgreSQL Storage Package

```bash
dotnet add package Duende.Storage.PostgreSQL
```

## 2. Configure Storage in Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddUserManagement(options =>
    {
        // PostgreSQL storage
        options.AddPostgreSqlStore(
            builder.Configuration.GetConnectionString("UserManagement"));

        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });
```

## 3. Schema Creation

Duende User Management uses **document-based storage** — there are no EF Core migrations to run. The schema is managed automatically.

At startup, call `IDatabaseSchema.CreateIfNotExistsAsync()` to ensure the required tables exist:

```csharp
var app = builder.Build();

var schema = app.Services.GetRequiredService<IDatabaseSchema>();
await schema.CreateIfNotExistsAsync();

app.UseIdentityServer();
// ...
```

## 4. Connection String in appsettings.json

```json
{
  "ConnectionStrings": {
    "UserManagement": "Host=localhost;Database=usermanagement;Username=postgres;Password=secret"
  }
}
```

## Key Points

- **No EF Core migrations needed.** Storage is document-based, and the schema auto-creates via `CreateIfNotExistsAsync()`.
- `AddPostgreSqlStore()` must be called **inside** the `AddUserManagement()` options lambda, not at the top level.
- The `Duende.Storage.PostgreSQL` package provides the PostgreSQL implementation.
- For production, ensure proper connection pooling and credentials management.
