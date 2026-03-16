# Fixing the context.Fail() Issue

## The Problem

The issue is with `context.Fail()`. When you call `context.Fail()`, it causes authorization to be denied for that request. Even if another handler would call `context.Succeed()`, the `Fail()` takes precedence and the request is denied.

## The Fix

Remove the `context.Fail()` call. When a handler doesn't meet the condition, simply don't call `context.Succeed()` — this allows other handlers to still evaluate the requirement.

### Fixed Code:

```csharp
public class ScopeHandler : AuthorizationHandler<ApiAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ApiAccessRequirement requirement)
    {
        if (context.User.HasClaim("scope", "api.read"))
            context.Succeed(requirement);
        
        // Don't call Fail() — just don't call Succeed()
        // This means "no opinion" and other handlers can still satisfy the requirement
        return Task.CompletedTask;
    }
}
```

## Explanation

- `context.Succeed(requirement)` — marks the requirement as satisfied
- `context.Fail()` — vetoes authorization, blocking all other handlers
- Not calling either — means "I have no opinion", other handlers can still try

In most cases, you should avoid calling `context.Fail()` unless you specifically want to deny access regardless of other handlers.
