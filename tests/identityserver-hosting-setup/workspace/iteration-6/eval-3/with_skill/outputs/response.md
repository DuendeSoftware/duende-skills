# ASP.NET Identity with IdentityServer

```bash
dotnet add package Duende.IdentityServer.AspNetIdentity
```

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddDbContext<ApplicationDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// 1. ASP.NET Identity first
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 2. Then IdentityServer + the bridge
builder.Services.AddIdentityServer(options =>
    {
        options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    })
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication()
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## What `AddAspNetIdentity<TUser>` does
- `IProfileService` – uses `IUserClaimsPrincipalFactory` to add claims to tokens
- `IResourceOwnerPasswordValidator` – password grant support
- Wraps `IUserClaimsPrincipalFactory`, calling the previously registered one and adding IdentityServer-specific claims

You must call **both** `AddIdentity` (ASP.NET Identity) and `AddAspNetIdentity` (the bridge), in that order. Alternatively use the template: `dotnet new duende-is-aspid -n IdentityServer`.
