# Integrating ASP.NET Identity with IdentityServer

To integrate ASP.NET Identity with your IdentityServer project, you need to configure both systems. Here's how:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure the database context
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Set up ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Add IdentityServer
builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.UseIdentityServer();

app.MapDefaultControllerRoute();

app.Run();
```

## Explanation

- `AddIdentity<ApplicationUser, IdentityRole>()` registers ASP.NET Identity services including UserManager and SignInManager.
- `AddEntityFrameworkStores<ApplicationDbContext>()` configures EF Core as the backing store for users and roles.
- `AddDefaultTokenProviders()` adds token providers for password reset, email confirmation, etc.
- `AddIdentityServer()` registers IdentityServer services.
- `AddAspNetIdentity<ApplicationUser>()` bridges ASP.NET Identity with IdentityServer, allowing IdentityServer to use ASP.NET Identity for user authentication.

The `AddAspNetIdentity` call configures IdentityServer to use ASP.NET Identity's user store and integrates the user management system with IdentityServer's token issuance pipeline.
