# Custom Claims and Inactive User Handling

```csharp
using Microsoft.AspNetCore.Identity;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders()
    .AddClaimsPrincipalFactory<CustomClaimsPrincipalFactory>();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

For disabling inactive users, you could implement a custom validator that checks if the user is active before issuing tokens. You'd need to hook into the authentication pipeline to reject inactive users.
