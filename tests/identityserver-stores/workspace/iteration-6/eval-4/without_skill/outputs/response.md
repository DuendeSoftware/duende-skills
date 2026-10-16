```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm)))
    .AddOperationalStore(o =>
    {
        o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm));
        o.EnableTokenCleanup = true;
        o.RemoveConsumedTokens = true;
        o.ConsumedTokenCleanupDelay = 300; // seconds
    })
    .AddServerSideSessions();
```

`AddServerSideSessions()` uses the EF-based `IServerSideSessionStore` provided by the operational store, so you need a migration for the new `ServerSideSessions` table:
```bash
dotnet ef migrations add ServerSideSessions -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```
(Server-side sessions are a Business/Enterprise edition feature.) Expired sessions are cleaned by the same cleanup job.
