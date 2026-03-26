# Grouping Admin Endpoints with Authorization

You can use `MapGroup` to group your admin endpoints and apply a shared authorization policy. Here's how:

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
    options.AddPolicy("admin", policy =>
        policy.RequireRole("admin"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));
app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints grouped
var adminGroup = app.MapGroup("/admin")
    .RequireAuthorization("admin");

adminGroup.MapGet("/users", () => Results.Ok(new[] { "alice", "bob" }));
adminGroup.MapPost("/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

The `MapGroup("/admin")` creates a route group that prefixes all endpoints with `/admin`. Calling `.RequireAuthorization("admin")` on the group applies the admin policy to all endpoints within it. The individual endpoints (`/users` GET and POST) are then registered on `adminGroup` and inherit both the route prefix and the authorization requirement.
