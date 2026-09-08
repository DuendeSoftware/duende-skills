# User Management Storage with PostgreSQL (and do you need migrations?)

Short answer: use `AddPostgreSqlStore()` inside `AddUserManagement()`, and **no — you do not run EF Core migrations**. Duende User Management storage is document-based; the schema is created for you at startup by `IDatabaseSchema.CreateIfNotExistsAsync()`.

## 1. Package

```bash
dotnet add package Duende.Storage.PostgreSQL
```

## 2. Configure the Store

`AddPostgreSqlStore()` is configured **inside** the `AddUserManagement()` options lambda, taking a standard PostgreSQL connection string:

```csharp
using Duende.UserManagement;
using Duende.Storage;

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        options.AddPostgreSqlStore(
            builder.Configuration.GetConnectionString("UserManagement"));

        // ...OTP dispatcher, etc.
    });
```

`appsettings.json`:

```json
"ConnectionStrings": {
  "UserManagement": "Host=localhost;Port=5432;Database=usermgmt;Username=app;Password=secret"
}
```

## 3. Schema Creation at Startup

Ensure the schema exists before the app handles requests:

```csharp
var app = builder.Build();

var schema = app.Services.GetRequiredService<IDatabaseSchema>();
await schema.CreateIfNotExistsAsync();   // creates tables if they don't exist yet

app.UseIdentityServer();
app.Run();
```

`CreateIfNotExistsAsync()` is idempotent — it creates the required tables the first time and is a no-op on subsequent runs.

## Do I need to run migrations?

**No.** User Management storage is **document-based**, not an EF Core model:

- There are **no `dotnet ef migrations add` / `dotnet ef database update` steps**.
- There is no `DbContext` to maintain, no migration history table, and no per-release migration files to check in.
- Schema provisioning is handled entirely by `IDatabaseSchema.CreateIfNotExistsAsync()`, which you call at startup (or run once during deployment).

For controlled production deploys where the app process shouldn't have DDL permissions, you can run `CreateIfNotExistsAsync()` from a dedicated bootstrap/migration step (a startup task or a one-off admin command) rather than on every app boot — but it's still the same document-store schema call, not EF migrations.

## Summary

- Package: `Duende.Storage.PostgreSQL`.
- Call `options.AddPostgreSqlStore(connectionString)` **inside** `AddUserManagement()`.
- Call `IDatabaseSchema.CreateIfNotExistsAsync()` at startup to auto-create the schema.
- No EF Core migrations — storage is document-based.
