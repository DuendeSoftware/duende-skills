You can require authentication globally by configuring a `FallbackPolicy` on the authorization options. The fallback policy applies to any endpoint that doesn't have its own authorization rules, and you can exempt individual endpoints with `.AllowAnonymous()`.

Don't forget to add the authorization middleware (`app.UseAuthorization()`) after `app.UseAuthentication()` — otherwise the policy is never evaluated.

Updated `Program.cs`:

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

builder.Services.AddAuthorization(options =>
{
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

// Public health check
app.MapGet("/health", () => Results.Ok("healthy"))
    .AllowAnonymous();

app.Run();
```

Notes:

- `FallbackPolicy` applies when an endpoint has no other authorization metadata, so this makes everything require an authenticated user by default.
- `RequireAuthenticatedUser()` is the requirement that enforces a signed-in user.
- `.AllowAnonymous()` on `/health` opts it out of the fallback policy so it stays public.
- The middleware order (`UseAuthentication` then `UseAuthorization`) is important; both must be registered before endpoints are matched.
