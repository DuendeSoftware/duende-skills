# Custom ScopeRequirement and ScopeHandler for Space-Delimited JWT Scopes

When IdentityServer is configured with `EmitScopesAsSpaceDelimitedStringInJwt = true`, scopes arrive in the JWT as a single space-delimited string (e.g., `"catalog.read catalog.write profile"`) rather than as individual claims. The built-in `RequireClaim("scope", "catalog.read")` checks for an exact match against the full claim value, so it won't work in this scenario. You need a custom authorization handler that splits the string and checks for the individual scope.

## ScopeRequirement

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}
```

The requirement is a simple data class that implements `IAuthorizationRequirement` and holds the expected scope value.

## ScopeHandler

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is null)
        {
            // No scope claim present — return without calling Succeed or Fail.
            // Not calling Succeed() means "I have no opinion" — other handlers
            // can still satisfy the requirement.
            return Task.CompletedTask;
        }

        // Handle both array claims and space-delimited string
        var scopes = scopeClaim.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }

        // Important: Do NOT call context.Fail() here.
        // Fail() is a hard veto that blocks all other handlers.
        // Simply not calling Succeed() means "I don't know" — other handlers may still succeed.
        return Task.CompletedTask;
    }
}
```

### Key Design Decisions

1. **`Split(' ', StringSplitOptions.RemoveEmptyEntries)`** — Handles the space-delimited format. This also handles edge cases like double spaces.

2. **No `context.Fail()` call** — This is critical. `context.Fail()` is a **hard veto** that prevents any other handler from satisfying the requirement, even if they would succeed. By not calling `Succeed()`, the handler expresses "no opinion", leaving the door open for other handlers. Only call `Fail()` when you need to guarantee denial (e.g., a security blocklist check).

3. **`context.Succeed(requirement)`** — Called only when the scope matches. This signals that this handler has determined the requirement is satisfied.

## Registration in Program.cs

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

// Register the custom handler in DI
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    // Use the custom ScopeRequirement instead of RequireClaim
    options.AddPolicy("catalog.read", policy =>
        policy.Requirements.Add(new ScopeRequirement("catalog.read")));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(new[]
{
    new { Id = 1, Name = "Widget", Price = 9.99 },
    new { Id = 2, Name = "Gadget", Price = 19.99 }
})).RequireAuthorization("catalog.read");

app.MapPost("/products", (object product) => Results.Created("/products/3", product));
app.MapDelete("/products/{id}", (int id) => Results.NoContent());

app.MapGet("/admin/users", () => Results.Ok(new[] { "alice", "bob" }));
app.MapPost("/admin/users", (object user) => Results.Created("/admin/users/3", user));

app.MapGet("/documents/{id}", (int id) =>
    Results.Ok(new { Id = id, Title = "Quarterly Report", Department = "finance", OwnerId = "user-1" }));
app.MapPut("/documents/{id}", (int id, object doc) => Results.NoContent());

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## How It All Fits Together

1. The `ScopeRequirement` defines *what* needs to be checked (the scope name).
2. The `ScopeHandler` defines *how* to check it (split the claim, look for a match).
3. The handler is registered in DI as `IAuthorizationHandler` so the authorization system discovers it.
4. The policy uses `policy.Requirements.Add(new ScopeRequirement("catalog.read"))` instead of `RequireClaim`, connecting the requirement to the handler.
5. When a request arrives, the authorization middleware finds all handlers for `ScopeRequirement`, invokes them, and checks if any called `Succeed()`.
