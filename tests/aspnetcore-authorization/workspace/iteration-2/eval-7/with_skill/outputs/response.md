# Fixing context.Fail() — Hard Veto Problem

## The Problem

The issue is that `context.Fail()` is a **hard veto** — it **permanently denies** authorization regardless of what any other handler says. Even if you have another handler that would call `context.Succeed(requirement)`, the `Fail()` call takes precedence and blocks all other handlers from granting access.

In ASP.NET Core's authorization system:
- **`context.Succeed(requirement)`** = "I approve this requirement"
- **`context.Fail()`** = "I actively DENY this, and no other handler can override me"
- **Not calling either** = "I have no opinion — let other handlers decide"

Your `ScopeHandler` is calling `Fail()` when the scope claim is missing, which means if a user doesn't have the `api.read` scope but *does* have another handler that should grant access (e.g., an admin role handler), they will still be denied.

## The Fix

Remove the `context.Fail()` call. Simply don't call `context.Succeed()` when the condition isn't met — this means "no opinion" and allows other handlers to still satisfy the requirement:

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

        // Not calling Succeed() means "I have no opinion" —
        // other handlers can still satisfy the requirement
        return Task.CompletedTask;
    }
}
```

## Key Takeaway

Only use `context.Fail()` when you need to **guarantee denial** even if other handlers would approve — for example, a security blocklist check or account suspension check. In the vast majority of cases, simply omit the `Succeed()` call and let the authorization system decide based on whether *any* handler succeeded.

The mental model:
- Multiple **requirements** in a policy use AND logic (all must be satisfied)
- Multiple **handlers** for the same requirement use OR logic (any can satisfy it)
- `context.Fail()` breaks the OR logic by vetoing everything
