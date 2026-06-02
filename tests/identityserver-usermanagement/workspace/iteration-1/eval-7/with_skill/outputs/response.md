# Fixing Storage Configuration Location

## The Problem

Storage configuration methods like `AddSqliteStore()`, `AddPostgreSqlStore()`, or `AddSqlServerStore()` **must be called inside the `AddUserManagement()` options lambda**, not at the top level of your service configuration.

## Incorrect (causes errors):

```csharp
// ❌ WRONG — storage configured outside AddUserManagement
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddUserManagement();

// This won't work — there's no AddSqliteStore on the top-level builder
builder.Services.AddSqliteStore("Data Source=users.db");  // ❌ Error!
```

## Correct:

```csharp
// ✅ CORRECT — storage configured inside AddUserManagement options lambda
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddUserManagement(options =>
    {
        options.AddSqliteStore("Data Source=users.db");  // ✅ Inside the lambda
    });
```

## Why This Matters

The `AddUserManagement()` method accepts a configuration lambda where all User Management-specific settings belong — including storage, OTP dispatchers, and migration options. The storage methods (`AddSqliteStore`, `AddPostgreSqlStore`, `AddSqlServerStore`) are extension methods on the User Management options object, not on `IServiceCollection` or the IdentityServer builder.

Configuring storage outside the lambda means User Management has no storage provider registered, which causes runtime errors when it tries to persist or retrieve user data.

## Also Note

- User Management uses **document-based storage** — you do NOT need EF Core migrations.
- Call `IDatabaseSchema.CreateIfNotExistsAsync()` at startup to auto-create the schema.
