# Scope-Based Authorization for Products API

Here's how to add scope-based authorization policies for your products API endpoints.

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
    options.AddPolicy("CatalogRead", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    options.AddPolicy("CatalogWrite", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// GET /products — requires catalog.read scope
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("CatalogRead");

// POST /products — requires catalog.write scope
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

1. Two policies are defined: `CatalogRead` requires the `scope` claim with value `catalog.read`, and `CatalogWrite` requires `catalog.write`.
2. `.RequireAuthorization("CatalogRead")` is applied to GET /products.
3. `.RequireAuthorization("CatalogWrite")` is applied to POST /products.
4. The `RequireClaim` method performs an exact match on the claim type and value.
