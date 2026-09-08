To make every endpoint require authentication by default, set a `FallbackPolicy` on the authorization options. The `FallbackPolicy` is applied to any endpoint that has **no** authorization metadata of its own, so it becomes your secure-by-default gate. You then opt specific endpoints out with `.AllowAnonymous()`.

Two things are required for this to work:

1. Register authorization with a `FallbackPolicy` that calls `RequireAuthenticatedUser()`.
2. Add `app.UseAuthorization()` to the pipeline **after** `app.UseAuthentication()`.

Here is the updated `Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });

// Secure-by-default: every endpoint requires an authenticated user
// unless it explicitly opts out with AllowAnonymous().
builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints — now protected by the fallback policy
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints — protected by the fallback policy
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));

app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoints — protected by the fallback policy
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));

app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check — explicitly public
app.MapGet("/health", () => Results.Ok("healthy"))
    .AllowAnonymous();

app.Run();
```

### Why this works

- **`FallbackPolicy` vs `DefaultPolicy`** — `FallbackPolicy` runs on endpoints with **no** authorization metadata at all, which is exactly what "require auth everywhere by default" needs. `DefaultPolicy` only applies when `[Authorize]`/`.RequireAuthorization()` is present without a named policy.
- **Middleware order matters** — `UseAuthentication()` establishes the identity from the JWT; `UseAuthorization()` then evaluates the fallback policy. Authorization must come after authentication, and both should sit before your endpoints.
- **`.AllowAnonymous()`** adds `AllowAnonymousAttribute` metadata to the `/health` endpoint. The fallback policy is skipped whenever anonymous metadata is present, so the health check stays publicly reachable while everything else is locked down.

This is the "fail closed" approach: opt endpoints *out* of auth explicitly rather than remembering to opt each one *in*.
