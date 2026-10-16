## What's wrong

`context.Fail()` marks the whole authorization as **failed**, and that can't be overridden. In ASP.NET Core, handlers for a requirement are all run, and normally any one `Succeed` is enough (OR semantics across handlers). But if any handler calls `Fail()`, `context.HasSucceeded` becomes false, so the user is denied even though another handler called `Succeed`.

## Fix

Don't call `Fail()` when the claim is just missing. Only call `Succeed()` when the check passes, and otherwise do nothing:

```csharp
public class ScopeHandler : AuthorizationHandler<ApiAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ApiAccessRequirement requirement)
    {
        if (context.User.HasClaim("scope", "api.read"))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

If the requirement isn't succeeded by any handler, it fails by default. Reserve `Fail()` for cases where access must be denied no matter what other handlers say (e.g. a blocked account).
