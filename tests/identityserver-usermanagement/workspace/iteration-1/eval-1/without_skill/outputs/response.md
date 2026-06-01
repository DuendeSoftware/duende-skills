# Adding User Management to IdentityServer

Duende IdentityServer provides identity and access management. For user management, you typically integrate with ASP.NET Core Identity. Here's how to set up a user store with passwordless email OTP login and SQLite.

## 1. Add NuGet Packages

```bash
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
```

## 2. Create a User DbContext

```csharp
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

public class ApplicationDbContext : IdentityDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options) { }
}
```

## 3. Update Program.cs

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite("Data Source=users.db"));

builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<IdentityUser>()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## 4. Run EF Migrations

```bash
dotnet ef migrations add InitialCreate
dotnet ef database update
```

## 5. OTP Email Setup

For passwordless OTP login, you'll need to implement a custom token provider and email sender. ASP.NET Identity supports token-based flows through `UserManager.GenerateUserTokenAsync()`. You'd configure an email service (e.g., via `IEmailSender`) to dispatch the codes.

```csharp
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
```

## Notes

- SQLite works for development but consider PostgreSQL or SQL Server for production.
- You'll need to create login/registration Razor Pages that handle the OTP flow.
- EF Core migrations are required when the schema changes.
