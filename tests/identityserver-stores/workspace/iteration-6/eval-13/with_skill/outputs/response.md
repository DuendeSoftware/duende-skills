**Use the renamed EF registrations.** Starting with 8.1.0-preview.4:

```csharp
builder.Services.AddIdentityServer()
    .AddEntityFrameworkConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddEntityFrameworkOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    });
```

**EF Core is not deprecated.** The rename exists so the EF registrations can't be confused with the new opt-in **Duende Storage** (preview) registrations, `AddConfigurationStorage` / `AddOperationalStorage`. Duende Storage is an alternative, not a replacement; moving to it from EF is a planned data transfer with no automated tool. `AddConfigurationStore`/`AddOperationalStore` still work but are `[Obsolete]`, so it's just a warning. Options, schema, and migrations are unchanged (`ConfigurationDbContext`, `PersistedGrantDbContext`), so stay on EF Core and do a rename.
