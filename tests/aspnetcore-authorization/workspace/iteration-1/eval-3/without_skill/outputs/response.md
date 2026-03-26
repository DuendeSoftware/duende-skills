# Custom Scope Authorization Handler

When JWT scopes come as a space-delimited string, you need a custom authorization handler to parse them properly. Here's how to implement it.

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

## Registration

In your `Program.cs`, register the handler and create the policy:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.read", policy =>
        policy.Requirements.Add(new ScopeRequirement("catalog.read")));
});
```

The `ScopeHandler` is registered as an `IAuthorizationHandler` in DI so the authorization system can discover and invoke it. The policy uses `Requirements.Add` to wire up the custom requirement.

When a request comes in, the handler will extract the `scope` claim from the JWT, split it by spaces, and check if the required scope is present.
