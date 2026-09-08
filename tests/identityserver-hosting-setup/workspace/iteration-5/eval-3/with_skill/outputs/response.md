# Wiring ASP.NET Identity Together with IdentityServer

To use ASP.NET Identity as the user store for IdentityServer you configure **both** systems: ASP.NET Identity for user management, and IdentityServer bridged to it via the integration package.

## Install the integration package

```bash
dotnet add package Duende.IdentityServer.AspNetIdentity
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// EF Core DbContext for the identity store
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// 1. Register ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 2. Register IdentityServer and bridge it to ASP.NET Identity
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication() internally
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Why both calls are needed

- **`AddIdentity<ApplicationUser, IdentityRole>()`** configures ASP.NET Identity itself — the `UserManager`, `SignInManager`, `RoleManager`, cookie authentication, etc.
  - **`.AddEntityFrameworkStores<ApplicationDbContext>()`** tells Identity to persist users/roles through your EF Core `DbContext`.
  - **`.AddDefaultTokenProviders()`** registers the token providers used for email confirmation, password reset, and two-factor flows.
- **`AddIdentityServer().AddAspNetIdentity<ApplicationUser>()`** bridges ASP.NET Identity into IdentityServer.

## What `AddAspNetIdentity` registers

`AddAspNetIdentity<TUser>` wires up IdentityServer-specific services that know how to talk to ASP.NET Identity:

- **`IProfileService`** — this is the key one: it uses the `IUserClaimsPrincipalFactory` to **add the user's claims to issued tokens** (id_token / access token) and to run the profile/userinfo logic.
- **`IResourceOwnerPasswordValidator`** — supports the resource owner password grant against the Identity user store.
- A wrapper **`IUserClaimsPrincipalFactory`** that calls through to Identity's factory and layers on IdentityServer-specific claims (e.g. `sub`, `auth_time`, `idp`).

The important takeaway: without `AddAspNetIdentity`, IdentityServer has no `IProfileService` implementation tied to your users, so claims from your `ApplicationUser` would not flow into tokens.

> Tip: the `duende-is-aspid` template scaffolds this exact integration if you want a pre-configured starting point.
