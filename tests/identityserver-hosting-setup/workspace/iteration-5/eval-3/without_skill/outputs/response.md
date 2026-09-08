# Integrating ASP.NET Identity with Duende IdentityServer

You need the bridge package that connects ASP.NET Identity to IdentityServer, then register both systems.

## Install

```bash
dotnet add package Duende.IdentityServer.AspNetIdentity
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// IdentityServer bridged to ASP.NET Identity
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Explanation

- **`AddIdentity<ApplicationUser, IdentityRole>()`** sets up ASP.NET Identity — `UserManager`, `SignInManager`, cookie auth, etc.
- **`.AddEntityFrameworkStores<ApplicationDbContext>()`** stores users and roles in your database via EF Core.
- **`.AddDefaultTokenProviders()`** enables the built-in providers for password reset, email confirmation, and 2FA tokens.
- **`.AddAspNetIdentity<ApplicationUser>()`** on the IdentityServer builder is what glues the two together. It registers an `IProfileService` implementation that pulls the user's claims (through the claims principal factory) so they end up in the issued tokens, and it configures IdentityServer to use the Identity cookie scheme for sign-in.

Order matters: call `AddIdentity(...)` **before** `AddIdentityServer().AddAspNetIdentity(...)`, because the IdentityServer integration builds on the Identity services already registered.
