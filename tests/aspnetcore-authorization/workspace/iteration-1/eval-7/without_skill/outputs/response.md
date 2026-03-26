# Fixing the Authorization Handler

## The Problem

The issue is with `context.Fail()` in your `ScopeHandler`. When you call `context.Fail()`, it acts as a **hard veto** — it tells the ASP.NET Core authorization system that authorization must be denied, and no other handler can override this. Even if you have another handler registered for `ApiAccessRequirement` that calls `context.Succeed()`, the `Fail()` from your scope handler takes precedence and blocks access.

## The Fix

Remove the `context.Fail()` call. Instead, only call `context.Succeed(requirement)` when the scope is present:

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

When your handler doesn't call `context.Succeed()`, it essentially has "no opinion" on the requirement. This allows other handlers to still evaluate and potentially satisfy the requirement. The authorization system will only deny access if no handler calls `Succeed()`.

## How Authorization Evaluation Works

ASP.NET Core evaluates all handlers for a given requirement:

- If any handler calls `Fail()`, the requirement is denied (hard veto)
- If at least one handler calls `Succeed()` and none call `Fail()`, the requirement passes
- If no handler calls `Succeed()` or `Fail()`, the requirement is denied

So the pattern is: call `Succeed()` when your condition is met, and simply return without calling anything when it's not. Only use `Fail()` when you need to explicitly deny access regardless of other handlers.
