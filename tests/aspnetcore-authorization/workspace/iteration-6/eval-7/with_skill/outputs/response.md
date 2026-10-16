## What's wrong

`context.Fail()` is a **hard veto**. Once any handler calls it, the authorization result is a failure, even if another handler calls `Succeed()` for the same requirement. So your `ScopeHandler` stops other handlers from granting access.

Not calling `Succeed()` means "I have no opinion". Handlers for the same requirement have OR semantics: any one succeeding is enough, as long as none has called `Fail()`. Multiple *requirements* in a policy have AND semantics.

## Fix

Only succeed when the check passes, and otherwise return without doing anything:

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
        // Not calling Succeed() = "I don't know"; other handlers may still succeed.
        // If none does, the requirement fails by default.

        return Task.CompletedTask;
    }
}
```

Both handlers must be registered:

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, ScopeHandler>();
builder.Services.AddSingleton<IAuthorizationHandler, OtherAccessHandler>();
```

Reserve `context.Fail()` for cases where you must guarantee denial no matter what other handlers say, such as a security blocklist check.
