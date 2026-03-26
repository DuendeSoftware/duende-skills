# Combining Client Scope and User Role in a Single Policy

When protecting API endpoints, it's critical to check **both** the client's scope (what the client application is allowed to do) and the user's claims (what the user is allowed to do). The DELETE endpoint for products is a destructive operation that should require both levels of permission.

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
    // Policy combining client scope AND user role
    options.AddPolicy("catalog.delete", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "catalog.write");  // Client-level permission
        policy.RequireRole("admin");                      // User-level permission
    });
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

// DELETE requires both catalog.write scope AND admin role
app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("catalog.delete");

// Admin endpoints
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check
app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Why Check Both Scope and Role?

In an OAuth 2.0 system, there are two distinct layers of authorization:

1. **Client scope (`scope` claim)** — Represents what the **client application** is permitted to do. Scopes are granted when the access token is issued and define the boundaries of what the client can request on behalf of a user. For example, a mobile app might be granted `catalog.read` and `catalog.write` scopes, while a reporting tool might only get `catalog.read`.

2. **User role/claims (`role` claim)** — Represents what the **user** is permitted to do. Even if a client has the `catalog.write` scope, the user operating that client might not have the `admin` role needed to delete products.

### Why both matter:

- **A malicious client could request broad scopes**, but the user may not have permission to perform the operation. Checking the user's role ensures that only authorized users can perform destructive actions.

- **A privileged user operating through a restricted client** should be limited by that client's scopes. An admin user using a read-only reporting tool shouldn't be able to delete products through it, even though their role would allow it.

- **Defense in depth** — By requiring both checks, you create a layered security model. The client must be authorized to perform the action, AND the user must have the right claims. This aligns with the OAuth 2.0 Security Best Current Practice.

### The policy in detail:

```csharp
policy.RequireClaim("scope", "catalog.write");  // Client has write permission
policy.RequireRole("admin");                      // User has admin role
```

Multiple requirements in a single policy use **AND logic** — all requirements must be satisfied for the policy to pass. This is exactly what we want: the token must have the scope AND the user must have the role.
