```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        // Keep original claim names (name, role) instead of the legacy XML URI mapping
        options.MapInboundClaims = false;

        options.TokenValidationParameters.NameClaimType = "name";
        options.TokenValidationParameters.RoleClaimType = "role";
        options.TokenValidationParameters.ValidateAudience = true;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.MapGet("/me", (HttpContext ctx) => ctx.User.Identity?.Name).RequireAuthorization();
app.MapGet("/admin", () => "admin").RequireAuthorization(p => p.RequireRole("admin"));

app.Run();
```

Why: with `MapInboundClaims = false`, the `name` and `role` claims keep their JWT names, so `User.Identity.Name` and `IsInRole` only work if `NameClaimType`/`RoleClaimType` point to those names. Authentication middleware must precede authorization.
