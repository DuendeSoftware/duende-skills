# Configuring FallbackPolicy for Secure-by-Default Authorization

To make all endpoints require authentication by default while keeping `/health` publicly accessible, configure a `FallbackPolicy` in `AddAuthorization` and use `.AllowAnonymous()` on the health endpoint.

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
    // FallbackPolicy applies to all endpoints that don't have an explicit [Authorize] attribute.
    // This makes the application secure-by-default — every endpoint requires authentication
    // unless explicitly opted out with AllowAnonymous.
    options.FallbackPolicy = new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints — protected by FallbackPolicy (require authenticated user)
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints — also protected by FallbackPolicy
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));

app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint — also protected by FallbackPolicy
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));

app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check — publicly accessible, opted out of FallbackPolicy
app.MapGet("/health", () => Results.Ok("healthy"))
    .AllowAnonymous();

app.Run();
```

## Key Points

- **`FallbackPolicy`** is applied to endpoints that have **no** `[Authorize]` attribute. By setting it to require authenticated users, all endpoints become protected by default.
- **`AllowAnonymous()`** explicitly opts the `/health` endpoint out of the fallback policy, making it accessible without authentication.
- **Middleware ordering** is critical: `app.UseAuthentication()` must come before `app.UseAuthorization()` so that the user identity is established before authorization decisions are made.
- This is the recommended "fail closed" pattern — deny access by default and explicitly allow public endpoints rather than trying to remember to protect every new endpoint.
