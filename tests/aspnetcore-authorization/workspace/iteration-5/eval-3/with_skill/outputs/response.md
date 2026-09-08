When scopes arrive as a single **space-delimited string** in the JWT (this happens when IdentityServer has `EmitScopesAsSpaceDelimitedStringInJwt = true`), a plain `RequireClaim("scope", "catalog.read")` won't match, because the whole claim value is something like `"catalog.read catalog.write"` — not an exact `"catalog.read"`. The fix is a custom requirement + handler that splits the claim on spaces.

The critical detail: **the handler must not call `context.Fail()` when the scope is missing.** Simply returning without calling `Succeed()` means "no opinion" and lets other handlers still satisfy the requirement. Calling `Fail()` is a hard veto that permanently blocks the requirement even if another handler would approve it.

```csharp
using Microsoft.AspNetCore.Authorization;

// Requirement: which scope must be present
public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}

// Handler: parse the (possibly space-delimited) scope claim
public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is null)
        {
            // No opinion — do NOT call Fail(); let other handlers try.
            return Task.CompletedTask;
        }

        // Works whether the scope is a single space-delimited string
        // ("catalog.read catalog.write") or a single value.
        var scopes = scopeClaim.Value.Split(
            ' ', StringSplitOptions.RemoveEmptyEntries);

        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }

        // Otherwise: no Succeed(), no Fail() — "no opinion".
        return Task.CompletedTask;
    }
}
```

Registration and policy in `Program.cs`:

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

// Register the handler in DI so the requirement is actually evaluated.
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
}))
.RequireAuthorization("catalog.read");

// ... remaining endpoints unchanged ...

app.Run();
```

### Why this shape

- **`ScopeRequirement : IAuthorizationRequirement`** is just a marker carrying the required scope string. The requirement says *what* must hold; the handler says *how* to evaluate it.
- **`ScopeHandler : AuthorizationHandler<ScopeRequirement>`** overrides `HandleRequirementAsync`, splits the claim with `Split(' ', ...)`, and only calls `Succeed()` on a match.
- **`AddSingleton<IAuthorizationHandler, ScopeHandler>()`** — a handler that isn't registered in DI is never invoked, and the policy would silently deny every request. Handlers are typically registered as singletons since they hold no per-request state.
- **`policy.Requirements.Add(new ScopeRequirement("catalog.read"))`** wires the requirement into the named policy so `.RequireAuthorization("catalog.read")` triggers the handler.
