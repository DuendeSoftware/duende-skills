# Combined Scope + Role Policy for DELETE Endpoint

When protecting API endpoints in an OAuth/OIDC-secured application, you should check **both** the client's scope and the user's role. These represent different dimensions of authorization:

- **Scopes** represent what the *client application* is permitted to do
- **Roles/Claims** represent what the *user* is permitted to do

A malicious or misconfigured client could request broad scopes, but the user may not have permission. Conversely, a privileged user operating through a restricted client should be limited by that client's scopes.

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
    options.AddPolicy("delete-product", policy =>
    {
        policy.RequireClaim("scope", "catalog.write"); // Client permission
        policy.RequireRole("admin");                    // User permission
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

// DELETE requires both client scope AND user role
app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("delete-product");

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Why Check Both?

When multiple requirements are added to a single policy (like `RequireClaim` and `RequireRole`), they use **AND logic** — all must be satisfied.

This is important because:

1. **Scopes represent client permissions.** The OAuth client requested and was granted the `catalog.write` scope by the authorization server. This is about what the *application* is allowed to do, not the user.

2. **Roles represent user permissions.** The `admin` role comes from the user's identity claims and represents what the *user* is allowed to do.

3. **Both must pass.** An admin user using a client without `catalog.write` scope should be denied. A non-admin user using a client with `catalog.write` should also be denied. Only when both the client has the scope AND the user has the role should the delete operation succeed.

This two-layered authorization model is fundamental to properly securing APIs in an OAuth 2.0 / OpenID Connect architecture.
