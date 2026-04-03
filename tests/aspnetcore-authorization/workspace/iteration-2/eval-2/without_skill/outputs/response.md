# Adding Scope-Based Authorization to Products API

You can create authorization policies that check for specific scopes in the JWT access token. Here's how to set up policies for reading and writing products.

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
    options.AddPolicy("CatalogRead", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    options.AddPolicy("CatalogWrite", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("CatalogRead");

app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("CatalogWrite");

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## How It Works

- `RequireClaim("scope", "catalog.read")` checks that the access token has a `scope` claim with the value `catalog.read`.
- Each policy is given a name and applied to the endpoint with `.RequireAuthorization("PolicyName")`.
- The policies are registered centrally via `AddAuthorization`, making them reusable across endpoints.
