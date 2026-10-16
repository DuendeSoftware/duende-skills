# EF Core server-side sessions (SQL Server)

Packages: `Duende.BFF.EntityFramework`, `Microsoft.EntityFrameworkCore.SqlServer`.

```csharp
builder.Services.AddBff(options =>
    {
        options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
    })
    .ConfigureOpenIdConnect(o => { /* ... */ })
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    });
```

Cleanup runs as a background service (`EnableSessionCleanup` defaults to true) at the interval set above.

Create the schema with migrations:

```
dotnet ef migrations add Sessions -c SessionDbContext -o Migrations/SessionDb
dotnet ef database update -c SessionDbContext
```

appsettings:
```json
"ConnectionStrings": { "BffSessions": "Server=...;Database=BffSessions;Trusted_Connection=True;TrustServerCertificate=True" }
```

Also: configure Data Protection with a shared key store when running multiple nodes.
