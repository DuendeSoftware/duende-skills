# Combining Client Scope and User Role in a Single Policy

When protecting an API endpoint with IdentityServer, you should check **both** the client's scope (what the application is allowed to do) and the user's claims (what the user is allowed to do). This is because scopes and roles represent different authorization dimensions.

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
    // Combined policy: requires BOTH client scope AND user role
    options.AddPolicy("catalog-admin-delete", policy =>
    {
        policy.RequireClaim("scope", "catalog.write"); // Client-level permission
        policy.RequireRole("admin");                    // User-level permission
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
    .RequireAuthorization("catalog-admin-delete");

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

**Scopes represent client permissions** — they describe what the *client application* is permitted to do. A scope like `catalog.write` means "this application has been granted write access to the catalog API." Scopes are consented to during the OAuth flow and embedded in the access token.

**Roles (and other user claims) represent user permissions** — they describe what the *user* is permitted to do. The `admin` role means "this user has administrative privileges."

### Why both matter:

1. **A malicious or misconfigured client** could request broad scopes. If you only check the scope, any user accessing through that client would have delete access — even non-admins.

2. **A privileged user using a restricted client** should be limited by that client's permissions. If you only check the `admin` role, a read-only client application could be used to delete products, even though the client was only granted read scopes.

3. **Defense in depth**: Checking both ensures that:
   - The client application was explicitly granted the `catalog.write` scope
   - The user has the `admin` role
   - Both conditions must be true simultaneously for the delete to proceed

This is a key principle in OAuth 2.0 API authorization: **scopes constrain the client, claims constrain the user, and both must be satisfied.**

## Policy Composition

In the policy builder, `RequireClaim(...)` and `RequireRole(...)` are added as separate *requirements*. Multiple requirements in a single policy use **AND** logic — all requirements must pass for the policy to succeed. This is exactly what we want: the client must have the scope AND the user must have the role.
