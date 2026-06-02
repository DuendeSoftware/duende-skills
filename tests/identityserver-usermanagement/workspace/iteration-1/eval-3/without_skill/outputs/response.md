# Setting Up PostgreSQL Storage for User Management with IdentityServer

For production user storage with IdentityServer, you can use PostgreSQL with ASP.NET Core Identity and Entity Framework Core.

## 1. Add Packages

```bash
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
```

## 2. Configure DbContext

```csharp
public class ApplicationDbContext : IdentityDbContext<IdentityUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options) { }
}
```

## 3. Update Program.cs

```csharp
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<IdentityUser>()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

## 4. Run Database Migrations

Yes, you do need to run EF Core migrations:

```bash
dotnet ef migrations add InitialIdentity
dotnet ef database update
```

Every time you change the schema (e.g., add custom user properties), you'll need to create and apply a new migration.

## Notes

- PostgreSQL is a solid choice for production with good performance and reliability.
- Consider using connection pooling (e.g., PgBouncer) for high-traffic scenarios.
- Store connection strings securely using user secrets or environment variables.
