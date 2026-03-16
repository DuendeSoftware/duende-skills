# The `context.Fail()` Problem — Hard Veto in Authorization Handlers

## What's Wrong

The issue is the call to `context.Fail()`. In ASP.NET Core authorization, **`context.Fail()` is a hard veto** — it immediately and permanently denies authorization for this request, regardless of what any other handler does.

When your `ScopeHandler` calls `context.Fail()` because the user doesn't have the `api.read` scope, it blocks **all other handlers** from satisfying the `ApiAccessRequirement`. Even if you have another handler that checks for a different condition (like an admin role override, or a different claim) and calls `context.Succeed(requirement)`, the `Fail()` veto takes precedence.

## The Fix

Remove the `context.Fail()` call. When a handler can't satisfy the requirement, it should simply **not call `context.Succeed()`** — this means "I have no opinion." Other handlers registered for the same requirement can still evaluate and potentially satisfy it.

### Before (broken):

```csharp
public class ScopeHandler : AuthorizationHandler<ApiAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ApiAccessRequirement requirement)
    {
        if (!context.User.HasClaim("scope", "api.read"))
            context.Fail();   // ❌ Hard veto — blocks ALL other handlers
        else
            context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
```

### After (fixed):

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
        // other handlers can still satisfy this requirement
        return Task.CompletedTask;
    }
}
```

## How Authorization Handler Resolution Works

ASP.NET Core authorization evaluates handlers with these rules:

1. **Multiple requirements** in a policy use **AND** logic — all must be satisfied.
2. **Multiple handlers** for the same requirement use **OR** logic — any one can satisfy it.
3. **`context.Succeed(requirement)`** — marks the requirement as satisfied by this handler.
4. **Not calling `Succeed()`** — means "I don't know / no opinion." The requirement remains unsatisfied by this handler, but other handlers can still try.
5. **`context.Fail()`** — a hard veto. Authorization is **denied immediately**, regardless of any other handler's result. This overrides even successful calls to `Succeed()` from other handlers.

## When Should You Use `context.Fail()`?

Only use `context.Fail()` when you need to **guarantee denial** regardless of what other handlers say. Legitimate use cases include:

- A security blocklist check (e.g., the user's account is locked or revoked)
- A mandatory compliance check that must never be bypassed
- An IP-based restriction that overrides all other access

In the vast majority of authorization handlers, simply omitting the `Succeed()` call is the correct approach.
