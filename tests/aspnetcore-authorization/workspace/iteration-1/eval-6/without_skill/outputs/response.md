# Combining Scope and Role Requirements

To require both a scope and a role, define a policy with both requirements.

## Updated Program.cs

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
    options.AddPolicy("catalog-admin-delete", policy =>
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
    .RequireAuthorization("catalog-admin-delete");

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Explanation

The policy includes both `RequireClaim("scope", "catalog.write")` and `RequireRole("admin")`. In ASP.NET Core, multiple requirements in a single policy use AND logic — both must be satisfied.

This means the request must come from a token that has the `catalog.write` scope AND the user must have the `admin` role. This ensures that the client has been granted write access and the user actually has admin privileges.
