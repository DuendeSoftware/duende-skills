# Scope-Based Authorization Policies for Products API

To protect your products API with scope-based authorization, define named policies that check for specific scope claims in the access token, then apply them to your minimal API endpoints using `.RequireAuthorization()`.

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
    options.AddPolicy("catalog.read", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    options.AddPolicy("catalog.write", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// GET /products requires the 'catalog.read' scope
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog.read");

// POST /products requires the 'catalog.write' scope
app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("catalog.write");

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

- **`RequireClaim("scope", "catalog.read")`** checks that the access token contains a `scope` claim with the value `catalog.read`. This is the standard way to enforce scope-based authorization in ASP.NET Core.
- Each policy is registered via `builder.Services.AddAuthorization()` and referenced by name on the endpoint using `.RequireAuthorization("policy-name")`.
- Scopes represent what the *client application* is permitted to do — they are set during the OAuth token request. This is distinct from user-level claims like roles.
- If IdentityServer emits scopes as a space-delimited string (via `EmitScopesAsSpaceDelimitedStringInJwt`), you would need a custom `IAuthorizationHandler` that splits the string. The `RequireClaim` approach works when scopes arrive as individual claim values.
