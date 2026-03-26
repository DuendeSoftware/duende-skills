# Server-Side Sessions with EF Core

To persist BFF sessions in SQL Server:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();

builder.Services.AddDbContext<SessionDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions")));

builder.Services.AddBff()
    .AddServerSideSessions();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

This configures server-side sessions backed by a SQL Server database. You'll need to create migrations for the session store.
