# Server-Side Sessions with EF Core and SQL Server

## Setup

First, add the EF Core package:

```bash
dotnet add package Duende.BFF.EntityFramework
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
```

## Configuration

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

    options.Scope.Clear();
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

## Migrations

Generate and apply EF Core migrations for the session store:

```bash
dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext
dotnet ef database update
```

## Key Points

- **`AddEntityFrameworkServerSideSessions`** persists sessions in SQL Server via EF Core — the cookie only carries a session ID, keeping cookie size small.
- **`AddSessionCleanupBackgroundProcess()`** runs a background task that cleans up expired sessions at the configured interval.
- **`SessionCleanupInterval = TimeSpan.FromMinutes(10)`** sets the cleanup to run every 10 minutes.
- **Do NOT use `AddServerSideSessions()` alone** for production — that uses in-memory storage which is lost on restart and can't be shared across instances.
