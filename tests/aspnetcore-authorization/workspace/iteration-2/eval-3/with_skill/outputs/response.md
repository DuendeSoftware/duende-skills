# Custom ScopeRequirement and ScopeHandler for Space-Delimited JWT Scopes

When IdentityServer is configured with `EmitScopesAsSpaceDelimitedStringInJwt = true`, scopes arrive as a single space-delimited string rather than individual claim values. The built-in `RequireClaim` won't work in this case — you need a custom authorization handler that splits the scope string.

## ScopeRequirement

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}
```

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
            return Task.CompletedTask; // No opinion — let other handlers try
        }

        // Handle both array claims and space-delimited string
        var scopes = scopeClaim.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }

        // Not calling Succeed() means "no opinion" — other handlers may still satisfy the requirement
        return Task.CompletedTask;
    }
}
```

## Registration in `Program.cs`

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

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

app.MapGet("/health", () => Results.Ok("healthy"));

app.Run();
```

## Key Design Decisions

- **`ScopeRequirement`** implements `IAuthorizationRequirement` and carries the expected scope as a property.
- **`ScopeHandler`** extends `AuthorizationHandler<ScopeRequirement>` and uses `Split(' ')` to parse the space-delimited scope string.
- The handler **never calls `context.Fail()`** — it either calls `context.Succeed(requirement)` when the scope matches, or does nothing ("no opinion"). This allows other handlers to still satisfy the requirement if registered.
- The handler is registered in DI as `IAuthorizationHandler` using `AddSingleton<IAuthorizationHandler, ScopeHandler>()`.
- The policy uses `policy.Requirements.Add(new ScopeRequirement(...))` instead of `RequireClaim`, pointing the authorization system to the custom handler.
