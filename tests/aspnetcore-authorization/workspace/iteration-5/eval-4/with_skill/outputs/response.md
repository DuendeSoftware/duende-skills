Define the `admin` policy centrally with `RequireRole("admin")`, create a `MapGroup("/admin")` that carries `.RequireAuthorization("admin")`, and register the individual endpoints on that group. Every route added to the group inherits the group's authorization, so you define the rule once.

Updated `Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

// Central policy definition
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("admin", policy =>
        policy.RequireRole("admin"));
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
app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin group — shared authorization applied once to the whole group
var adminGroup = app.MapGroup("/admin")
    .RequireAuthorization("admin");

adminGroup.MapGet("/users", () => Results.Ok(new[] { "alice", "bob" }));
adminGroup.MapPost("/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

### Notes

- **`options.AddPolicy("admin", policy => policy.RequireRole("admin"))`** defines the policy once, centrally. Referencing it by name (rather than sprinkling `[Authorize(Roles = "admin")]` on each endpoint) keeps the role string in a single place and makes the rule easy to change or test.
- **`app.MapGroup("/admin").RequireAuthorization("admin")`** creates a route group with a shared `/admin` prefix and applies the policy to every endpoint in it.
- The users endpoints are registered on **`adminGroup`** (`adminGroup.MapGet("/users", ...)` → `/admin/users`), not directly on `app`, so they inherit the group's authorization automatically.
- **Role claim mapping note:** with a JWT, `RequireRole` checks the `ClaimsIdentity.RoleClaimType` (by default `role` / `http://schemas.microsoft.com/ws/2008/06/identity/claims/role`). If IdentityServer emits roles under a different claim type, either map it via `TokenValidationParameters.RoleClaimType = "role"` on the JWT bearer options or use `RequireClaim("role", "admin")` instead.
