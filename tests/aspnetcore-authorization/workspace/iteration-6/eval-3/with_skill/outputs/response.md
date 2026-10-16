When `EmitScopesAsSpaceDelimitedStringInJwt` is on (or the provider emits `scope` as one string), `RequireClaim("scope", "catalog.read")` fails, so a custom requirement and handler is needed.

## Requirement and handler

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
}

public class ScopeHandler : AuthorizationHandler<ScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ScopeRequirement requirement)
    {
        // Handles both multiple "scope" claims (array) and a single space-delimited claim
        var scopes = context.User.FindAll("scope")
            .SelectMany(c => c.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries));

        if (scopes.Contains(requirement.Scope, StringComparer.Ordinal))
        {
            context.Succeed(requirement);
        }

        // Not calling Succeed = "no opinion"; deliberately no context.Fail()
        return Task.CompletedTask;
    }
}
```

## Registration (Program.cs)

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.read", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.Requirements.Add(new ScopeRequirement("catalog.read"));
    });
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok(/* ... */))
   .RequireAuthorization("catalog.read");
```

Points to remember:
- **Register the handler in DI.** Without `AddSingleton<IAuthorizationHandler, ScopeHandler>()`, the requirement has no handler and the policy silently denies everything.
- **Don't call `context.Fail()`.** It is a hard veto that overrides other handlers. Omitting `Succeed()` means other handlers can still satisfy the requirement, and the requirement fails by default if none do.
- Multiple requirements in a policy use AND logic. Multiple handlers for one requirement use OR logic.
