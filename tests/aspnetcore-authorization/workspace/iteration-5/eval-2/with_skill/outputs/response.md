Define two named authorization policies at startup — one per scope — then attach them to the corresponding endpoints with `.RequireAuthorization("<policy>")`. Because the API is protected by IdentityServer-issued access tokens, the scope arrives as a `scope` claim, so `RequireClaim("scope", "...")` is the right check.

Remember to also add `app.UseAuthorization()` after `app.UseAuthentication()`, otherwise the policies are never enforced.

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
    // Client must present the catalog.read scope to read products
    options.AddPolicy("catalog.read", policy =>
        policy.RequireClaim("scope", "catalog.read"));

    // Client must present the catalog.write scope to create products
    options.AddPolicy("catalog.write", policy =>
        policy.RequireClaim("scope", "catalog.write"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// GET requires the read scope
app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
}))
.RequireAuthorization("catalog.read");

// POST requires the write scope
app.MapPost("/products", (object product) => Results.Created("/products/3", product))
    .RequireAuthorization("catalog.write");

app.MapDelete("/products/{id}", (int id) => Results.NoContent());

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

### Notes

- **`RequireClaim("scope", "catalog.read")`** succeeds when the access token contains a `scope` claim with that value. This models the *client's* permission (what the calling application is allowed to do), which is exactly what OAuth scopes represent.
- **`.RequireAuthorization("catalog.read")`** attaches the named policy to a single Minimal API endpoint. Referencing policies by name keeps the scope strings centralized in one place instead of scattered across endpoints.
- If your IdentityServer emits scopes as a single **space-delimited string** rather than multiple claims (`EmitScopesAsSpaceDelimitedStringInJwt = true`), `RequireClaim` won't match a substring. In that case switch to a custom `ScopeRequirement`/`ScopeHandler` that splits the claim on spaces. For standard multi-valued scope claims, the `RequireClaim` approach above is sufficient.
