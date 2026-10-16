Fail closed: set a `FallbackPolicy` requiring an authenticated user, then opt `/health` out with `AllowAnonymous()`.

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
    // Applied to endpoints with NO authorization metadata
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
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

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

// Explicitly public
app.MapGet("/health", () => Results.Ok("healthy")).AllowAnonymous();

app.Run();
```

Key points:
- **`FallbackPolicy`** applies to any endpoint without authorization metadata (no `[Authorize]`/`RequireAuthorization`). Products, admin, and documents are now protected, and so is anything added later.
- **`DefaultPolicy`** is different: it applies when `[Authorize]`/`RequireAuthorization()` is used with no policy name. Setting it as well is optional.
- **`AllowAnonymous()`** on `/health` opts it out, which suits health checks.
- **`app.UseAuthorization()`** was missing from the original and must come after `UseAuthentication()`. Without it, no policy is enforced.
- Endpoint-specific policies (scopes, roles) can be layered on later with `RequireAuthorization("policy")`, which overrides the fallback for that endpoint.
