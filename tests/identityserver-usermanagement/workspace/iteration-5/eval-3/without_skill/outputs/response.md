# Configuring PostgreSQL Storage for User Management

For a production PostgreSQL setup with IdentityServer + user management, the standard stack is ASP.NET Core Identity persisted through Entity Framework Core using the **Npgsql** provider. Here's the storage configuration and what you need to know about migrations.

## 1. Packages

```bash
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Design
```

## 2. DbContext + Connection String

```csharp
public class AppDbContext : IdentityDbContext<IdentityUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
}
```

`appsettings.json`:

```json
"ConnectionStrings": {
  "Default": "Host=localhost;Port=5432;Database=usermgmt;Username=app;Password=secret"
}
```

## 3. Register in Program.cs

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddAspNetIdentity<IdentityUser>();
```

## Do you need migrations?

**Yes.** Because this uses EF Core, you must create and apply migrations to provision the schema in PostgreSQL:

```bash
dotnet ef migrations add InitialIdentity
dotnet ef database update
```

In production, apply migrations as part of your deployment pipeline rather than automatically on app startup. If you also persist IdentityServer's operational/configuration data (grants, clients) in the database, you'd add those DbContexts and their migrations too (`ConfigurationDbContext`, `PersistedGrantDbContext` from `Duende.IdentityServer.EntityFramework`).

A common pattern is to run migrations at startup in non-production environments:

```csharp
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}
```

## Summary

- Use the **Npgsql** EF Core provider (`UseNpgsql(...)`) with your PostgreSQL connection string.
- Persist users via ASP.NET Identity's `AddEntityFrameworkStores<AppDbContext>()`.
- **Migrations are required** — run `dotnet ef migrations add` + `dotnet ef database update`, ideally in your deploy pipeline.

> Note: If "Duende User Management" refers to a specific product with its own storage abstraction, its documented storage/registration API may differ from the EF Core approach above — check its docs for provider-specific setup.
