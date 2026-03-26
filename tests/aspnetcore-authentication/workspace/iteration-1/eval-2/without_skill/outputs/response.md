# JWT Bearer Authentication

Here's how to set up JWT Bearer authentication for your API:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";

        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateAudience = true,
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

This sets up JWT Bearer authentication with the specified authority and audience. The `NameClaimType` and `RoleClaimType` map ASP.NET Core's `User.Identity.Name` and role-based authorization to the correct JWT claims.
