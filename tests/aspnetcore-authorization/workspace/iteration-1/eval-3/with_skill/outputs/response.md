# Custom Scope Handler for Space-Delimited JWT Scopes

When IdentityServer is configured with `EmitScopesAsSpaceDelimitedStringInJwt = true`, scopes arrive in the JWT as a single space-delimited string rather than an array of claims. The built-in `RequireClaim` won't match individual scopes in that case. You need a custom `IAuthorizationRequirement` and `IAuthorizationHandler`.

## ScopeRequirement.cs

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }

    public ScopeRequirement(string scope)
    {
        Scope = scope;
    }
}
```

## ScopeHandler.cs

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        // Find the scope claim
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is null)
        {
            // No scope claim at all — don't call Fail(), just return.
            // Not calling Succeed() means "I have no opinion" — other handlers
            // for this requirement can still attempt to satisfy it.
            return Task.CompletedTask;
        }

        // Handle both space-delimited string and individual claim values
        var scopes = scopeClaim.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries);

        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }

        // Important: do NOT call context.Fail() here.
        // Fail() is a hard veto that prevents any other handler from satisfying
        // this requirement. Simply not calling Succeed() means "I couldn't satisfy
        // this requirement" and lets other handlers try.

        return Task.CompletedTask;
    }
}
```

## Updated Program.cs

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

// Register the custom scope handler in DI
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

// Apply the policy to endpoints
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

## Key Design Decisions

1. **`ScopeRequirement` implements `IAuthorizationRequirement`** with a `Scope` property that specifies which scope to check for.
2. **`ScopeHandler` extends `AuthorizationHandler<ScopeRequirement>`** — the generic base class provides the typed `HandleRequirementAsync` method.
3. **`Split(' ')` handles space-delimited strings** — when IdentityServer emits scopes as `"openid profile catalog.read"`, this correctly parses each individual scope.
4. **No `context.Fail()` on mismatch** — this is critical. `Fail()` is a hard veto that blocks all other handlers. By simply not calling `Succeed()`, we express "no opinion" and allow other handlers (if any) to satisfy the requirement.
5. **Registered as `IAuthorizationHandler` in DI** — without this registration, the policy would silently deny all requests because no handler would ever evaluate the requirement.
