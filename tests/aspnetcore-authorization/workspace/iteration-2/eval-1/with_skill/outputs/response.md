# Configure FallbackPolicy for Default Authentication + AllowAnonymous Health Endpoint

To secure all endpoints by default while keeping `/health` public, configure a `FallbackPolicy` in your authorization setup. The `FallbackPolicy` is applied to any endpoint that doesn't have an explicit `[Authorize]` attribute, making your application "secure by default."

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
    // FallbackPolicy: applied to endpoints with NO [Authorize] attribute
    // Setting this makes all endpoints require authentication by default
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Products endpoints — now require authentication via FallbackPolicy
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

// Health check — explicitly public
app.MapGet("/health", () => Results.Ok("healthy"))
    .AllowAnonymous();

app.Run();
```

## Key Points

- **`FallbackPolicy`** is applied to endpoints that have **no** `[Authorize]` attribute. By setting it to `RequireAuthenticatedUser()`, every endpoint becomes authenticated-by-default.
- **`app.UseAuthorization()`** must be called **after** `app.UseAuthentication()` — authentication establishes the identity, authorization decides access.
- The **`/health`** endpoint uses `.AllowAnonymous()` to opt out of the fallback policy, keeping it publicly accessible for monitoring and load-balancer health checks.
- This is different from `DefaultPolicy`, which is only applied when `[Authorize]` is used *without* specifying a policy name.
