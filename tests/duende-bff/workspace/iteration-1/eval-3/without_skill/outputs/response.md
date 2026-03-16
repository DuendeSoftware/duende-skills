# Server-Side Sessions with SQL Server

To use server-side sessions backed by SQL Server, you'll need the Entity Framework integration package:

```bash
dotnet add package Duende.BFF.EntityFramework
```

## Configuration

```csharp
builder.Services.AddBff()
    .AddServerSideSessions()
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    });
```

You'll also want to set up session cleanup:

```csharp
builder.Services.AddBff(options =>
{
    options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
});
```

Then run EF migrations:

```bash
dotnet ef migrations add InitialCreate -c SessionDbContext
dotnet ef database update
```

This stores sessions in SQL Server instead of in-memory, which is important for production deployments where you need sessions to survive restarts and be shared across multiple instances.
