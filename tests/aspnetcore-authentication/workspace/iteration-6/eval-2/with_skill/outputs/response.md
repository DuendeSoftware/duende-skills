```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";   // must match the ApiResource name

        options.MapInboundClaims = false;   // keep "name"/"role"/"sub" as-is

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.MapGet("/products", (HttpContext c) => Results.Ok(c.User.Identity?.Name))
   .RequireAuthorization();
app.MapGet("/admin", () => "ok")
   .RequireAuthorization(p => p.RequireRole("admin"));

app.Run();
```

Why: with `MapInboundClaims = false` the claims keep their JWT names. Setting `NameClaimType = "name"` and `RoleClaimType = "role"` tells ASP.NET Core which claims feed `User.Identity.Name` and `IsInRole`/`RequireRole`. Without mapping off, `sub` would become an XML URI and `User.FindFirst("sub")` would return null. `UseAuthentication` must precede `UseAuthorization`.
