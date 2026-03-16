# Scope-Based Authorization Policies for Products API

To protect your products API with scope-based authorization, define named policies using `RequireClaim("scope", ...)` and apply them to the appropriate endpoints.

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
    // Scope-based policies: scopes represent what the CLIENT is allowed to do
    options.AddPolicy("catalog:read", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    options.AddPolicy("catalog:write", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// GET /products — requires 'catalog.read' scope
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog:read");

// POST /products — requires 'catalog.write' scope
app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("catalog:write");

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

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

## How It Works

1. **`RequireClaim("scope", "catalog.read")`** checks that the access token contains a `scope` claim with the value `catalog.read`. This validates what the *client application* is permitted to do.
2. **`.RequireAuthorization("catalog:read")`** on the endpoint applies that named policy, so the framework evaluates it before the endpoint handler runs.
3. **Scope vs. user claims**: Scopes represent client-level permissions (what the application is allowed to request). For full API security, you should also check user-level claims (roles, department, etc.) in addition to scopes. This example only checks client scopes — see the skill guidance on combining both for production APIs.

## Important Notes

- `RequireClaim` does an **exact match** on the claim value. If your IdentityServer emits scopes as a single space-delimited string (when `EmitScopesAsSpaceDelimitedStringInJwt = true`), you'll need a custom `IAuthorizationHandler` that splits the string. See the custom scope handler pattern.
- Policy names are arbitrary strings — use a naming convention that makes sense for your domain.
