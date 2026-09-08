## The problem

The culprit is `context.Fail()`. In ASP.NET Core's authorization pipeline, calling `context.Fail()` is a definitive, hard failure — it forces the requirement to be denied and that decision **cannot be overridden by any other handler**, even one that calls `context.Succeed()`. `Fail()` effectively vetoes the entire requirement.

By contrast, when a handler simply does nothing (neither `Succeed()` nor `Fail()`), it is expressing "no opinion." The requirement can then still be satisfied by a different handler that calls `Succeed()`.

Because multiple handlers registered for the same requirement work as an OR (any one succeeding is enough), your intent was for the *other* handler to be able to grant access. But this handler calls `Fail()` whenever the `api.read` scope is missing, which slams the door shut before the other handler's `Succeed()` can count. That's why users are denied.

## The fix

Just remove the `Fail()` call. Call `Succeed()` when the scope is present, and otherwise do nothing:

```csharp
public class ScopeHandler : AuthorizationHandler<ApiAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ApiAccessRequirement requirement)
    {
        if (context.User.HasClaim("scope", "api.read"))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

With this change, if the `api.read` scope isn't present the handler stays silent ("no opinion"), and the other handler is free to satisfy the requirement by calling `Succeed()`.

## Rule of thumb

Only use `context.Fail()` when you specifically need to block access unconditionally — a case where no other handler should be allowed to grant it (for example a global deny/blocklist rule). For normal permission checks, express approval with `Succeed()` and stay silent when your condition isn't met.
