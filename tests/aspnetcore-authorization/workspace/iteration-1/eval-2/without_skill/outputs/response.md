# Adding Scope-Based Authorization to Products API

You can use ASP.NET Core's policy-based authorization to enforce scope requirements on your API endpoints. Here's how to set it up:

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

## Explanation

The `AddAuthorization` method lets you define named policies. Each policy uses `RequireClaim` to check that the JWT token contains a `scope` claim with the expected value.

The `RequireAuthorization` method on the minimal API endpoint builder applies the named policy to that endpoint. When a request comes in, ASP.NET Core will check whether the token satisfies the policy before executing the handler.

Make sure the scopes are configured correctly on your identity provider side so that the access tokens actually contain these scope values.
