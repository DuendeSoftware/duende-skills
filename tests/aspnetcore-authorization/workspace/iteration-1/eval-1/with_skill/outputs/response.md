# Configuring FallbackPolicy with AllowAnonymous for /health

To make all endpoints require authentication by default while keeping `/health` publicly accessible, you need to configure a `FallbackPolicy` in the authorization options and apply `AllowAnonymous()` to the health endpoint.

The `FallbackPolicy` is applied to any endpoint that does **not** have an explicit `[Authorize]` attribute or `.RequireAuthorization()` call. By setting it to require authenticated users, you create a secure-by-default configuration where you must explicitly opt out of authentication using `AllowAnonymous()`.

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
    // FallbackPolicy: applied to endpoints with NO [Authorize] attribute
    // Setting this makes all endpoints require authentication by default
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints — now require authentication by default via FallbackPolicy
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}));

app.MapPost("/products", (object product) => Results.Created("/products/3", product));

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

// Admin endpoints — also require authentication via FallbackPolicy
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));

app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

// Documents endpoint
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));

app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Health check — explicitly allow anonymous access
app.MapGet("/health", () => Results.Ok("healthy"))
    .AllowAnonymous();

app.Run();
```

## Key Changes

1. **`builder.Services.AddAuthorization(options => { ... })`** — Registers the authorization services and configures a `FallbackPolicy` using `new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build()`. This ensures that any endpoint without an explicit authorization attribute will require an authenticated user.

2. **`app.UseAuthorization()`** — Added after `app.UseAuthentication()`. The middleware order is critical: authentication must run first to establish the user's identity, then authorization checks whether that identity has the required permissions. Without `UseAuthorization()`, the `FallbackPolicy` would not be enforced.

3. **`.AllowAnonymous()` on `/health`** — The health check endpoint is explicitly opted out of the FallbackPolicy using `.AllowAnonymous()`. This means unauthenticated requests can still reach this endpoint — essential for load balancers and health monitoring systems that don't carry tokens.

## Important Notes

- **FallbackPolicy vs DefaultPolicy**: The `DefaultPolicy` is what gets applied when you use `[Authorize]` with no policy name. The `FallbackPolicy` is applied to endpoints that have **no** `[Authorize]` attribute at all. Setting `FallbackPolicy` gives you a secure-by-default posture.

- **Middleware ordering**: `app.UseAuthentication()` must come before `app.UseAuthorization()`. If reversed, authorization would run before the user's identity is established, and all requests would be treated as unauthenticated.

- **Fail closed**: This approach follows the "fail closed" principle — access is denied by default, and you must explicitly grant public access. This is much safer than the alternative of relying on developers to remember to add `[Authorize]` to every endpoint.
