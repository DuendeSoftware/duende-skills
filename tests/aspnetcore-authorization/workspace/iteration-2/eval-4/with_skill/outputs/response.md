# Group Admin Endpoints with MapGroup and Shared Authorization Policy

Use `MapGroup` to group related endpoints under a common prefix and apply a shared authorization policy to the entire group.

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

// Group-level authorization for admin endpoints
var adminGroup = app.MapGroup("/admin")
    .RequireAuthorization("admin");

adminGroup.MapGet("/users", () => Results.Ok(new[] { "alice", "bob" }));
adminGroup.MapPost("/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check
app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## How It Works

- **`app.MapGroup("/admin")`** creates a route group with the `/admin` prefix. All endpoints registered on this group inherit the prefix.
- **`.RequireAuthorization("admin")`** applies the `"admin"` policy to the entire group, so both `GET /admin/users` and `POST /admin/users` require the `admin` role.
- The individual endpoints are registered on `adminGroup` (not on `app` directly), which means they get the group's route prefix and authorization policy automatically.
- The `"admin"` policy is centrally defined using `RequireRole("admin")` — this is cleaner than scattering `[Authorize(Roles = "admin")]` on each endpoint.
