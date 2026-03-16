# Custom Authorization Handler for Space-Delimited Scopes

When JWT scopes come as a space-delimited string, you need a custom handler to parse them.

## ScopeRequirement.cs

```csharp
using Microsoft.AspNetCore.Authorization;

public class ScopeRequirement : IAuthorizationRequirement
{
    public string Scope { get; }
    public ScopeRequirement(string scope) => Scope = scope;
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
        var scopeClaim = context.User.FindFirst("scope");
        if (scopeClaim is null)
        {
            context.Fail();
            return Task.CompletedTask;
        }

        var scopes = scopeClaim.Value.Split(' ');
        if (scopes.Contains(requirement.Scope))
        {
            context.Succeed(requirement);
        }
        else
        {
            context.Fail();
        }

        return Task.CompletedTask;
    }
}
```

## Program.cs Registration

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.read", policy =>
        policy.Requirements.Add(new ScopeRequirement("catalog.read")));
});
```

## Explanation

- `ScopeRequirement` defines what scope is needed.
- `ScopeHandler` parses the space-delimited scope string and checks if the required scope is present.
- The handler is registered in DI as `IAuthorizationHandler`.
- The policy uses the custom requirement instead of `RequireClaim`.
