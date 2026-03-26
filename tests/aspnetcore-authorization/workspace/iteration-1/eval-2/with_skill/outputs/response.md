# Adding Scope-Based Authorization Policies for Products API

To protect your products API with scope-based authorization, you need to define named authorization policies that check for specific scope claims, then apply those policies to the corresponding endpoints.

In an OAuth 2.0 / OpenID Connect setup with IdentityServer, scopes represent what the **client application** is permitted to do. When an access token is issued with a particular scope, it arrives as a `scope` claim in the JWT. You can use `RequireClaim("scope", ...)` to validate it.

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
    // Policy requiring the 'catalog.read' scope — for read operations
    options.AddPolicy("catalog.read", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    // Policy requiring the 'catalog.write' scope — for write operations
    options.AddPolicy("catalog.write", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// GET /products — requires the 'catalog.read' scope
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog.read");

// POST /products — requires the 'catalog.write' scope
app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("catalog.write");

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

1. **`builder.Services.AddAuthorization(options => { ... })`** — Registers the authorization services and defines two named policies:
   - `"catalog.read"` — requires the access token to contain a `scope` claim with value `catalog.read`
   - `"catalog.write"` — requires the access token to contain a `scope` claim with value `catalog.write`

2. **`.RequireAuthorization("catalog.read")`** on the GET endpoint — applies the `catalog.read` policy. Only requests with a valid token containing this scope will be allowed through.

3. **`.RequireAuthorization("catalog.write")`** on the POST endpoint — applies the `catalog.write` policy. Only clients that have been granted the `catalog.write` scope can create products.

## Important: Scope vs User Claims

Remember that **scopes represent client permissions, not user permissions**. The `scope` claim tells you what the client application is allowed to do — it doesn't tell you what the individual user is allowed to do. For comprehensive authorization, consider combining scope checks with user-level claims:

```csharp
// Example: combine scope + user role for production use
options.AddPolicy("catalog.write", policy =>
{
    policy.RequireClaim("scope", "catalog.write"); // Client permission
    policy.RequireRole("editor");                   // User permission
});
```

## Space-Delimited Scopes

If your IdentityServer is configured with `EmitScopesAsSpaceDelimitedStringInJwt = true`, the scopes arrive as a single space-separated string rather than individual claims. In that case, `RequireClaim("scope", "catalog.read")` will check for an exact match against the entire string, which won't work. You'd need a custom `IAuthorizationHandler` that splits the string. See the skill reference for a `ScopeHandler` implementation that handles this case.
