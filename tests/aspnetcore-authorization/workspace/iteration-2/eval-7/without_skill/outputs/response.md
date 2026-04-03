# Fixing the Authorization Handler

## The Problem

The issue is with the `context.Fail()` call. When you call `Fail()`, it tells the authorization system to deny the request immediately, even if there's another handler that could grant access. It's like a veto — once one handler says "fail," nothing else can override it.

## The Fix

Instead of calling `Fail()`, just don't call `Succeed()`. This way, your handler is saying "I can't help with this" but it doesn't block other handlers from potentially granting access.

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

## Why This Works

In ASP.NET Core authorization:
- Calling `Succeed()` means "I approve this"
- Calling `Fail()` means "I deny this and nobody can override me"
- Not calling either means "I have no opinion"

By removing `Fail()`, you allow the authorization system to check if any other handler can satisfy the requirement. The requirement will only fail if no handler calls `Succeed()`.
