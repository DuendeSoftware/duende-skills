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
    options.AddPolicy("catalog.read", policy =>
        policy.RequireAuthenticatedUser().RequireClaim("scope", "catalog.read"));

    options.AddPolicy("catalog.write", policy =>
        policy.RequireAuthenticatedUser().RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog.read");

app.MapPost("/products", (object product) => Results.Created("/products/3", product))
   .RequireAuthorization("catalog.write");

// remaining endpoints unchanged
app.MapDelete("/products/{id}", (int id) => Results.NoContent());
app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));
app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());
app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

Caveats:
- `RequireClaim("scope", "catalog.read")` matches a claim whose value is exactly that string. If the token has a single space-delimited `scope` claim (e.g. `"openid catalog.read"`), it won't match. Duende IdentityServer emits `scope` as a JSON array in access tokens, which JwtBearer expands into separate claims, so this works there. For other providers, use a custom handler that splits the value (see a `ScopeRequirement` approach).
- `UseAuthorization()` is required.
