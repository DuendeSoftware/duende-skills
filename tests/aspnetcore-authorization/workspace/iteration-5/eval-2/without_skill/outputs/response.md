You can define two named policies that each require the appropriate `scope` claim, then apply them to the `GET` and `POST` endpoints with `.RequireAuthorization()`. Scopes from a JWT access token typically show up as `scope` claims, so `RequireClaim` is the natural fit.

Also make sure `app.UseAuthorization()` is added after `app.UseAuthentication()`.

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
    options.AddPolicy("CatalogRead", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    options.AddPolicy("CatalogWrite", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}))
.RequireAuthorization("CatalogRead");

app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("CatalogWrite");

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

Summary:

- `AddPolicy(..., policy => policy.RequireClaim("scope", "..."))` registers each policy.
- `.RequireAuthorization("CatalogRead")` and `.RequireAuthorization("CatalogWrite")` bind them to the GET and POST endpoints.
- One caveat: if your identity provider emits all scopes in a single space-separated `scope` string, `RequireClaim` matches the whole value and won't find an individual scope. In that setup you'd need a custom requirement/handler that splits the claim.
