# Server-side BFF sessions with EF Core and SQL Server

By default Duende BFF stores the session in the cookie, which is fine for simple cases but not ideal for production — you can't revoke sessions server-side and the cookie grows large. Moving to server-side sessions backed by EF Core / SQL Server fixes that, and you can enable automatic cleanup of expired sessions.

Install the EF integration package:

```bash
dotnet add package Duende.BFF.EntityFramework
```

Then wire it up:

```csharp
using Duende.Bff;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("BffSessions");

builder.Services.AddBff(options =>
    {
        // clean up expired sessions on a schedule
        options.EnableSessionCleanup = true;
        options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
    })
    .AddServerSideSessions()
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(connectionString);
    });

// ... your authentication / OpenID Connect configuration ...

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

## Notes

- **`AddEntityFrameworkServerSideSessions`** registers the EF-backed session store and its `DbContext`, using SQL Server via `UseSqlServer` with your `ConnectionStrings:BffSessions` value.
- **`SessionCleanupInterval = TimeSpan.FromMinutes(10)`** together with `EnableSessionCleanup = true` runs a background job that deletes expired sessions every ten minutes.
- Storing sessions in the database means only a small session identifier goes in the cookie, and you can invalidate a user's session server-side.

## Create the tables

Generate and apply an EF migration so the session tables exist:

```bash
dotnet ef migrations add BffSessions -c SessionDbContext -o Data/Migrations
dotnet ef database update -c SessionDbContext
```

After that your BFF will persist sessions in SQL Server and prune expired ones automatically.
