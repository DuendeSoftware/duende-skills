# Server-Side Sessions with EF Core and SQL Server

```csharp
var builder = WebApplication.CreateBuilder(args);

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
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("offline_access");
})
.AddEntityFrameworkServerSideSessions(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
})
.AddSessionCleanupBackgroundProcess();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

## Setup Steps

1. Install the EF package: `dotnet add package Duende.BFF.EntityFramework`
2. Run migrations:
   ```bash
   dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext
   dotnet ef database update
   ```

## Key Points

- **`AddEntityFrameworkServerSideSessions`** persists session data in SQL Server. The cookie only carries a session ID, keeping it small and enabling server-side revocation.
- **`SessionCleanupInterval = TimeSpan.FromMinutes(10)`** configures how often expired sessions are purged from the database.
- **`AddSessionCleanupBackgroundProcess()`** registers the background service that performs the cleanup. Without it, expired sessions accumulate in the database.
- **Do NOT use `AddServerSideSessions()` alone** (without EF) in production — that stores sessions in memory, which is lost on restart and can't be shared across instances.
