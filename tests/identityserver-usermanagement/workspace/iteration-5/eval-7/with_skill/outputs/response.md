# Why Your Storage Configuration Is Failing

The problem is **where** your storage is configured. With Duende User Management, storage (`AddSqliteStore()`, `AddPostgreSqlStore()`, `AddSqlServerStore()`, etc.) **must be configured *inside* the `AddUserManagement()` options lambda** — not on the top-level `builder.Services` collection and not on the IdentityServer builder directly.

When you put the storage call at the top level, the User Management configuration pipeline never receives your store registration, so it can't resolve its storage services at startup — which is why you're seeing errors.

## ❌ What You Probably Have (incorrect)

```csharp
builder.Services.AddIdentityServer(/* ... */)
    .AddInMemoryClients(Config.Clients)
    .AddUserManagement(options =>
    {
        // OTP dispatcher, etc.
    });

// ❌ Storage configured at the top level, OUTSIDE AddUserManagement
builder.Services.AddSqliteStore("Data Source=users.db");
```

Configuring the store outside the lambda means it isn't attached to the User Management options, so User Management doesn't know which store to use. **This is the cause of the error.**

## ✅ The Correct Pattern

Move the storage call **inside** the `AddUserManagement(options => { ... })` lambda:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        // ✅ Storage goes INSIDE the options lambda
        options.AddSqliteStore("Data Source=users.db");

        // OTP dispatcher, etc. also go here
        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });
```

The same rule applies to every provider — `options.AddPostgreSqlStore(...)`, `options.AddSqlServerStore(...)` — they are all methods on the `options` object passed to `AddUserManagement`, not on `builder.Services`.

## Don't "Fix" This with EF Core Migrations

If you were about to reach for `dotnet ef migrations add` / `dotnet ef database update` to solve this — don't. It's unrelated. User Management storage is **document-based**; there are no EF Core migrations. The schema is created by calling `IDatabaseSchema.CreateIfNotExistsAsync()` at startup:

```csharp
var app = builder.Build();

var schema = app.Services.GetRequiredService<IDatabaseSchema>();
await schema.CreateIfNotExistsAsync();
```

## Summary

- **Cause:** storage was configured at the top level, outside `AddUserManagement()`.
- **Fix:** call `options.AddSqliteStore(...)` (or `AddPostgreSqlStore`/`AddSqlServerStore`) **inside** the `AddUserManagement(options => { ... })` lambda.
- **Not the fix:** EF Core migrations — storage is document-based; use `CreateIfNotExistsAsync()` for schema creation.
