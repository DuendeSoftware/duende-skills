# Requiring Both Scope and Role for DELETE Endpoint

You can combine multiple requirements in a single authorization policy to enforce both client and user permissions.

## Updated `Program.cs`

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("delete-product", policy =>
    {
        policy.RequireClaim("scope", "catalog.write");
        policy.RequireRole("admin");
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("delete-product");

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Why Check Both?

Checking both the scope and the role is important because they control different things. The scope is about what the application is allowed to do, while the role is about what the user is allowed to do. You want to make sure both the application and the user have the right permissions before allowing a destructive operation like delete.
