## What's wrong

The bug is the `context.Fail()` call. In ASP.NET Core authorization, `context.Fail()` is a **hard veto**: once *any* handler calls it, the whole requirement is denied for good, regardless of what any other handler does. It cannot be undone by a later `context.Succeed()`.

Not calling `Succeed()` and not calling `Fail()` means something completely different — it means **"I have no opinion."** The requirement can still be satisfied by another handler that *does* call `Succeed()`.

Here's the key model:

- A requirement is **satisfied** if at least one handler calls `context.Succeed(requirement)` **and** no handler has called `context.Fail()`.
- Multiple handlers for the same requirement are effectively **OR** logic — any one of them succeeding is enough… *unless* one of them vetoes with `Fail()`.

Your handler calls `context.Fail()` the moment the `api.read` scope claim is absent. Even though your *other* handler would happily call `Succeed()`, the `Fail()` from this handler overrides it and the user is denied. That's exactly the symptom you're seeing.

## The fix

Remove the `context.Fail()` call entirely. Only call `Succeed()` when your condition is met; otherwise do nothing and let other handlers have their say.

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
        // No else, no Fail(): "no opinion" — another handler may still succeed.

        return Task.CompletedTask;
    }
}
```

Now if this handler doesn't see `api.read`, it stays silent, and your second handler's `Succeed()` will satisfy the requirement.

## When `Fail()` is actually appropriate

Reserve `context.Fail()` for cases where you want to **guarantee denial** no matter what any other handler concludes — for example a security blocklist, a revoked-token check, or a "this account is locked" rule. In those cases the hard veto is exactly the behavior you want. For ordinary "does the user have this permission?" checks like scope validation, simply omit the `Succeed()` call and never call `Fail()`.
