# Grouping Admin Endpoints with MapGroup and Shared Authorization

Use `MapGroup` to organize related endpoints and apply authorization at the group level. This avoids repeating `.RequireAuthorization()` on each individual endpoint.

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
    // Centralized policy definition for admin access
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

// Admin endpoints — grouped with shared authorization policy
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

1. **`options.AddPolicy("admin", ...)`** defines the policy centrally using `RequireRole("admin")`. The policy checks that the authenticated user has the `admin` role claim.
2. **`app.MapGroup("/admin")`** creates a route group with the `/admin` prefix. All endpoints registered on the group inherit the group's route prefix and metadata.
3. **`.RequireAuthorization("admin")`** on the group applies the named policy to every endpoint within the group.
4. **Individual endpoints use `adminGroup.MapGet`** instead of `app.MapGet` — this registers them on the group rather than directly on the application, so they inherit the group-level authorization.

## Benefits of This Pattern

- **DRY**: Authorization is specified once at the group level, not repeated per endpoint.
- **Consistency**: Adding a new admin endpoint to the group automatically gets the same authorization policy.
- **Composability**: Groups can be nested, and each can add additional metadata like rate limiting, CORS, etc.
- **Centralized policies**: The policy is defined in `AddAuthorization` so it can be referenced by name throughout the application. If requirements change (e.g., adding a required scope), only the policy definition needs to be updated.
