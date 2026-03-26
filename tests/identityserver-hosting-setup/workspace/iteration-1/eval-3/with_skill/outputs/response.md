# Integrating ASP.NET Identity with IdentityServer

Here's how to wire up ASP.NET Identity and IdentityServer together:

## Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure the database for ASP.NET Identity
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Register IdentityServer and bridge to ASP.NET Identity
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## What `AddAspNetIdentity<ApplicationUser>()` Configures

Calling `.AddAspNetIdentity<ApplicationUser>()` after `AddIdentityServer()` registers several critical IdentityServer implementations:

1. **`IProfileService`** — This is the key integration point. It uses `IUserClaimsPrincipalFactory<ApplicationUser>` to read claims from ASP.NET Identity and add them to tokens (id_tokens and access tokens). When a token is requested, IdentityServer calls `GetProfileDataAsync` which delegates to the claims principal factory to build the user's claims.

2. **`IResourceOwnerPasswordValidator`** — Supports the `password` grant type by validating credentials against ASP.NET Identity's `UserManager`.

3. **`IUserClaimsPrincipalFactory`** — Wraps the previously registered factory (or the default one) and adds additional IdentityServer-specific claims on top.

## Registration Order

The order matters:
1. First, configure `AddIdentity<ApplicationUser, IdentityRole>()` to register ASP.NET Identity
2. Then, call `AddIdentityServer()` followed by `.AddAspNetIdentity<ApplicationUser>()` to bridge IdentityServer to ASP.NET Identity

`AddAspNetIdentity` must be called after `AddIdentity` because it depends on the ASP.NET Identity services being registered.

## NuGet Packages

```bash
dotnet add package Duende.IdentityServer.AspNetIdentity
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
```
