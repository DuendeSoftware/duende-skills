# Why `context.Fail()` Blocks All Other Handlers

## The Problem

The issue is that `context.Fail()` is a **hard veto** in ASP.NET Core's authorization system. When any handler calls `context.Fail()`, it **permanently** prevents authorization from succeeding for that requirement — regardless of whether another handler later calls `context.Succeed(requirement)`. This means if `ScopeHandler` doesn't find the `api.read` scope, it vetoes the entire requirement, and no other handler (even one that could otherwise grant access) can override that decision.

This is a critical distinction in the ASP.NET Core authorization pipeline:

| Method | Meaning |
|--------|---------|
| `context.Succeed(requirement)` | This handler is satisfied; requirement can pass if no Fail was called |
| `context.Fail()` | **Hard veto** — requirement CANNOT pass regardless of other handlers |
| *(not calling either)* | **No opinion** — this handler neither grants nor denies; other handlers can still satisfy the requirement |

The "no opinion" concept is key: **not calling `Succeed()` is not the same as calling `Fail()`**. When a handler simply doesn't call `Succeed()`, it expresses no opinion on the requirement, which allows other registered handlers to still satisfy it. This is the correct pattern for cooperative multi-handler authorization.

## The Fix

Remove the `context.Fail()` call entirely. The corrected handler should only call `context.Succeed(requirement)` when the condition is met, and simply do nothing otherwise:

```csharp
public class ScopeHandler : AuthorizationHandler<ApiAccessRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, ApiAccessRequirement requirement)
    {
        // Only call Succeed when the scope is present.
        // Do NOT call Fail() — just don't call Succeed().
        // Not calling Succeed() means "no opinion", allowing
        // other handlers to still satisfy this requirement.
        if (context.User.HasClaim("scope", "api.read"))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

## Why This Matters for Multi-Handler Scenarios

ASP.NET Core authorization allows multiple handlers to be registered for the same requirement. The framework evaluates all handlers and applies these rules:

1. If **any** handler calls `context.Fail()`, the requirement fails — period.
2. If **at least one** handler calls `context.Succeed(requirement)` and **no** handler calls `context.Fail()`, the requirement passes.
3. If **no** handler calls either `Succeed` or `Fail`, the requirement fails (no one granted access).

This design enables cooperative authorization patterns where different handlers can check different conditions (scopes, roles, IP addresses, time-of-day, etc.) for the same requirement. As long as at least one grants access and none vetoes, authorization succeeds.

## When Should You Use `context.Fail()`?

Reserve `context.Fail()` for cases where you want an unconditional denial that cannot be overridden, such as:

- The user's account is locked or suspended
- A security condition is violated (e.g., request from a blocked IP)
- Revoked permissions that must be enforced regardless of other handlers

For normal "I don't have the right claim" scenarios, simply not calling `Succeed()` is the correct approach — it means "no opinion" and lets other handlers have their say.
