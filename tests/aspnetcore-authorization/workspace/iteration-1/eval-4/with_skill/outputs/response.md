# Grouping Admin Endpoints with MapGroup and Shared Authorization

To group the `/admin/users` endpoints under a `MapGroup` with shared authorization, you define a named policy requiring the `admin` role and apply it to the route group. All endpoints registered on the group inherit the authorization requirement.

Here is the updated `Program.cs`:

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
    // Centrally defined admin policy — requires the 'admin' role
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

// Admin endpoints — grouped with shared authorization
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

1. **Centralized Policy Definition** — `options.AddPolicy("admin", policy => policy.RequireRole("admin"))` defines a single policy that checks for the `admin` role claim. This keeps authorization logic in one place rather than scattering role strings across endpoints.

2. **`app.MapGroup("/admin")`** — Creates a route group with the `/admin` prefix. All endpoints registered on this group will have `/admin` prepended to their route templates.

3. **`.RequireAuthorization("admin")`** — Applied to the group, this ensures that **every endpoint** within the group requires the `admin` policy. No need to add `.RequireAuthorization()` to each individual endpoint.

4. **Endpoints on the group** — `adminGroup.MapGet("/users", ...)` and `adminGroup.MapPost("/users", ...)` are registered on `adminGroup` instead of `app`. Their effective routes are `/admin/users` (the group prefix + the endpoint template).

## Benefits of MapGroup

- **DRY authorization** — Apply authorization once at the group level instead of repeating it on each endpoint.
- **Consistent routing** — All endpoints share the same prefix automatically.
- **Composable** — Groups can be nested, and each level can add its own filters, metadata, or authorization.
- **Easy to extend** — Adding new admin endpoints just requires registering them on `adminGroup`.

## Policy-Based Over Role Strings

Using `RequireRole("admin")` within a named policy is preferred over scattering `[Authorize(Roles = "admin")]` across controllers. If the role requirements change (e.g., you want to allow `it-ops` users too), you only change the policy definition in one place:

```csharp
options.AddPolicy("admin", policy =>
    policy.RequireRole("admin", "it-ops"));
```
