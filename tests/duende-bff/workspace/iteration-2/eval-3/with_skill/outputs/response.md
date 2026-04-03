Here's how to configure server-side sessions with EF Core and SQL Server, plus automatic session cleanup:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff(options =>
{
    options.SessionCleanupInterval = TimeSpan.FromMinutes(10); // Cleanup every 10 minutes
})
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    })
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    })
    .AddSessionCleanupBackgroundProcess(); // v4: registers a hosted service for periodic cleanup

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

Key points:

1. **`AddEntityFrameworkServerSideSessions`** — Persists session data in SQL Server via EF Core. The cookie only carries a session ID, keeping cookie size small and enabling server-initiated revocation.

2. **`AddSessionCleanupBackgroundProcess()`** — In BFF v4, session cleanup is a separate registration. This registers a `BackgroundService` that periodically removes expired sessions from the database.

3. **`SessionCleanupInterval = TimeSpan.FromMinutes(10)`** — Sets the cleanup interval to 10 minutes. The default is 10 minutes, but we're being explicit here per your requirement.

4. **Do NOT use `AddServerSideSessions()` alone in production** — `AddServerSideSessions()` without EF uses in-memory storage. Sessions are lost on restart and cannot be shared across instances. Always use `AddEntityFrameworkServerSideSessions()` for production.

You'll also need to create EF Core migrations for the session store:

```bash
dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext
dotnet ef database update
```

Make sure the `Duende.BFF.EntityFramework` package is installed:
```
dotnet add package Duende.BFF.EntityFramework
```
