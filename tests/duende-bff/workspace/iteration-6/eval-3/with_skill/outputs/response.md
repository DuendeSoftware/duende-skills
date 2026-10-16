# EF Core server-side sessions on SQL Server

```
dotnet add package Duende.BFF.EntityFramework
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
```

```csharp
builder.Services.AddBff(options =>
    {
        options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
    })
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("offline_access");
    })
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    })
    .AddSessionCleanupBackgroundProcess();   // v4: cleanup must be registered explicitly
```

Key points:
- In v4 `EnableSessionCleanup` is **removed**; `.AddSessionCleanupBackgroundProcess()` is what runs cleanup, at `SessionCleanupInterval` (10 minutes here, which is also the default).
- Create the schema:
```bash
dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext
dotnet ef database update
```
- With server-side sessions the cookie only carries a session id; tokens (including refresh token) live in the DB.
- For multiple instances also share Data Protection keys (e.g. `PersistKeysToDbContext`), otherwise cookies can't be decrypted across nodes.
- Don't use `AddServerSideSessions()` alone in production: in-memory, lost on restart, not shared.
