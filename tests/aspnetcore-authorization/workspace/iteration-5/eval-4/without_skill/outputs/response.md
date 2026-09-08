You can define an `admin` policy once with `RequireRole("admin")`, then use `MapGroup("/admin")` to group the endpoints and apply the policy to the whole group with `.RequireAuthorization("admin")`. Endpoints added to the group inherit that authorization.

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

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("admin", policy => policy.RequireRole("admin"));
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

var admin = app.MapGroup("/admin")
    .RequireAuthorization("admin");

admin.MapGet("/users", () => Results.Ok(new[] { "alice", "bob" }));
admin.MapPost("/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

Summary:

- The `admin` policy is defined centrally in `AddAuthorization` using `RequireRole("admin")`.
- `app.MapGroup("/admin")` groups the endpoints under the `/admin` prefix.
- `.RequireAuthorization("admin")` on the group enforces the policy for every endpoint in it.
- The users endpoints are registered on the `admin` group (`admin.MapGet("/users", ...)`), so they map to `/admin/users` and are all protected without repeating the attribute.
