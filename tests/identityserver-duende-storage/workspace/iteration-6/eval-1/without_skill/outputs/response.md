I'm not aware of a product called "Duende Storage" with a documented API, so I can't show its exact packages. The established way to persist clients, resources, grants and sessions in a SQL database with Duende IdentityServer is the EF Core stores (`Duende.IdentityServer.EntityFramework`), which I'll show with SQLite.

**Packages**
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="10.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.0" />
```

**Program.cs**
```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var cs = builder.Configuration.GetConnectionString("IdentityServer") ?? "Data Source=identityserver.db";
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer(o => o.EmitStaticAudienceClaim = true)
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlite(cs, s => s.MigrationsAssembly(asm)))
    .AddOperationalStore(o =>
    {
        o.ConfigureDbContext = b => b.UseSqlite(cs, s => s.MigrationsAssembly(asm));
        o.EnableTokenCleanup = true;
    });

builder.Services.AddRazorPages();
var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();
    var ctx = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
    ctx.Database.Migrate();
    if (!ctx.Clients.Any())
    {
        foreach (var c in Config.Clients) ctx.Clients.Add(c.ToEntity());
        foreach (var r in Config.IdentityResources) ctx.IdentityResources.Add(r.ToEntity());
        foreach (var s in Config.ApiScopes) ctx.ApiScopes.Add(s.ToEntity());
        ctx.SaveChanges();
    }
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```
Generate migrations first: `dotnet ef migrations add Init -c ConfigurationDbContext -o Migrations/Configuration` and the same for `PersistedGrantDbContext`. Server-side sessions need `.AddServerSideSessions()` (Business edition or higher). If "Duende Storage" is a newer package, check its docs; my knowledge may not cover it.
